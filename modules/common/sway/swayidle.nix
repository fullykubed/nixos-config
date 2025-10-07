{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Create a systemd service that runs after resume to ensure monitors are turned on
  systemd.services.sway-resume-monitors = {
    description = "Turn on Sway monitors after resume";
    after = [ "suspend.target" ];
    wantedBy = [ "suspend.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = config.username;

      # Ensure we have the right environment
      Environment = [
        "WAYLAND_DISPLAY=wayland-1"
        "XDG_RUNTIME_DIR=/run/user/1000"
      ];

      # Try multiple times with a delay to ensure Sway is ready
      ExecStart = pkgs.writeShellScript "sway-resume-monitors" ''
        #!/bin/sh
        # Wait a moment for the system to stabilize
        sleep 2

        # Try to turn on monitors multiple times
        for i in 1 2 3; do
          ${pkgs.sway}/bin/swaymsg "output * dpms on" 2>/dev/null && exit 0
          sleep 1
        done

        # If we couldn't connect to sway, try with explicit display
        export SWAYSOCK=$(find /run/user/1000 -name "sway-ipc.*" 2>/dev/null | head -1)
        if [ -n "$SWAYSOCK" ]; then
          ${pkgs.sway}/bin/swaymsg "output * dpms on"
        fi
      '';
    };
  };

  # Also improve the swayidle service restart behavior
  systemd.user.services.swayidle = {
    unitConfig = {
      # Increase restart tolerance
      StartLimitIntervalSec = 30;
      StartLimitBurst = 10;
    };

    serviceConfig = {
      # Add restart delay to give sway time to stabilize
      RestartSec = 2;
    };
  };

  home-manager.users.${config.username} = {
    # This controls the lock screen and power savings modes
    services.swayidle = {
      enable = true;
      extraArgs = [
        "-d"
        "idlehint"
        (builtins.toString (60 * 5))
      ];
      timeouts = [
        # Enables the lock screen
        {
          timeout = 60 * 5;
          command = "${pkgs.swaylock}/bin/swaylock --color 000000 -fF";
        }

        # Turns off monitors
        {
          timeout = 60 * 5;
          command = ''${pkgs.sway}/bin/swaymsg "output * dpms off"'';
          resumeCommand = ''${pkgs.sway}/bin/swaymsg "output * dpms on"'';
        }

        # Suspends the system
        {
          timeout = 60 * 15;
          command = "${pkgs.systemd}/bin/systemctl suspend";
        }
      ];
      events = [
        {
          event = "before-sleep";
          command = ''${pkgs.sway}/bin/swaymsg "output * dpms off"'';
        }
        {
          event = "after-resume";
          # Use a script that waits for sway to be ready before sending commands
          command = "${pkgs.writeShellScript "sway-resume-dpms" ''
            #!/bin/sh
            # Wait for sway to be ready
            for i in 1 2 3 4 5; do
              ${pkgs.sway}/bin/swaymsg "output * dpms on" 2>/dev/null && exit 0
              sleep 0.5
            done
            # Final attempt with explicit socket detection
            export SWAYSOCK=$(find /run/user/$(id -u) -name "sway-ipc.*" 2>/dev/null | head -1)
            [ -n "$SWAYSOCK" ] && ${pkgs.sway}/bin/swaymsg "output * dpms on"
          ''}";
        }

        # For some reason, when resuming, sway does not properly swap to an "idle" state
        # until the user has provided some sort of input after resume. This is troublesome
        # b/c sometimes the system will resume when the user is not physically present and then
        # will never suspend again. This simulates a noop keypress after swayidle restarts
        # in order to begin tracking the idle state properly again
        {
          event = "after-resume";
          command = "${pkgs.wtype}/bin/wtype -d 2000 -k shift_l";
        }
      ];
    };
  };
}
