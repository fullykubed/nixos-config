{
  config,
  pkgs,
  lib,
  ...
}:
let
  configure-gtk = import ./configure-gtk.nix pkgs;

  scripts = pkgs.stdenv.mkDerivation rec {
    pname = "sway-scripts";
    version = "1.0";

    src = ./scripts;

    dontBuild = true;

    installPhase = ''
      mkdir -p $out/bin

      # Find all .sh files in the source directory
      for script in $(find ${src} -name "*.sh"); do
        script_name=$(basename $script .sh)
        cp $script $out/bin/$script_name
        chmod +x $out/bin/$script_name
      done
    '';
  };

  monitors = {
    middle = "DP-6";
    left = "DP-5";
    right = "DP-4";
  };
in
{
  # enable sway window manager
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      swaytools # tooling to help debug and setup sway
      swaylock # sway lock screen
      swayidle # sway idle timer
      waybar # status bar
      unstable.swayr # window switcher
      wl-clipboard
      wf-recorder
      mako # notification daemon
      libnotify # for scripting notifications
      sway-contrib.grimshot # screenshot tool
      slurp
      xdg-utils # for opening default programs when clicking links
      glib # gsettings
      dracula-theme # gtk theme
      wofi # menu / launcher
      ydotool # scripting CLI for wayland

      # Custom sway scripts
      scripts
      configure-gtk
    ];
  };

  environment.sessionVariables = {
    # Used for the notifications daemon settings
    SWAY_NOTIFICATION_OUTPUT = monitors.middle;
  };

  # Disable the login manager
  services.xserver.displayManager.lightdm.enable = false;

  # Portals are the mechanism for sharing audio and video across applications
  xdg.portal = {
    enable = true;

    # Only use for wl-roots based systems
    wlr.enable = true;

    # For screen sharing in gnome
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
  };

  # Systemd target so that we can start and stop background services
  # that depend on a sway session
  systemd.user.targets.sway-session = {
    description = "sway compositor session";
    documentation = [ "man:systemd.special" ];
    bindsTo = [ "graphical-session.target" ];
    wants = [ "graphical-session-pre.target" ];
    after = [ "graphical-session-pre.target" ];
  };

  # Starts swayrd for window switching
  systemd.user.services.swayrd = {
    description = "swayrd";
    enable = true;
    startLimitBurst = 3;
    startLimitIntervalSec = 15;
    wantedBy = [ "sway-session.target" ];
    after = [ "sway-session.target" ];
    path = [ pkgs.wofi ];
    environment = {
      RUST_BACKTRACE = "1";
    };
    serviceConfig = {
      ExecStart = "${pkgs.unstable.swayr}/bin/swayrd";
    };
  };

  home-manager.users.${config.username} = {

    xdg.configFile = {
      # Sets up mako config (notifications)
      "mako/config" = {
        text = ''
          default-timeout=15000
        '';
      };

      # Sets up waybar
      "waybar/config" = {
        source = ./waybar/config.json;
      };
    };

    programs.bash = {
      # Make sure the desktop entries show up in sway
      profileExtra = ''
        if [ "$(tty)" = "/dev/tty1" ]; then
          export XDG_CURRENT_DESKTOP=sway
          exec systemd-cat -t sway sway
        fi
      '';
    };

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
          command = ''${pkgs.sway}/bin/swaymsg "output * dpms on"'';
        }

        # For some reason, when resuming, sway does not properly swap to an "idle" state
        # until the user has provided some sort of input after resume. This is troublesome
        # b/c sometimes the system will resume when the user is not physically present and then
        # will never suspend again. This simulates a noop keypress after swayidle restarts
        # in roder to begin tracking the idle state properly again
        {
          event = "after-resume";
          command = "${pkgs.wtype}/bin/wtype -d 1000 -k shift_l";
        }
      ];
    };

    wayland.windowManager.sway =
      let
        swayModifier = "Mod4";
      in
      {
        enable = true;
        systemd = {
          enable = false;
        };
        config = {
          modifier = swayModifier;
          terminal = "alacritty";
          menu = "wofi";
          gaps = {
            inner = 10;
          };
          window = {
            border = 5;
          };

          # Handle the keybinds below for more flexibilitiy
          keybindings = { };

          bars = [ { command = "${pkgs.waybar}/bin/waybar"; } ];
        };

        extraConfig = ''
          # floating windows
          for_window [title="fzf-switcher"] floating enable
          for_window [title="Firefox — Sharing Indicator"] floating enable

          # These are the default sway keybindings
          bindsym ${swayModifier}+1 workspace number 1
          bindsym ${swayModifier}+2 workspace number 2
          bindsym ${swayModifier}+3 workspace number 3
          bindsym ${swayModifier}+4 workspace number 4
          bindsym ${swayModifier}+5 workspace number 5
          bindsym ${swayModifier}+6 workspace number 6
          bindsym ${swayModifier}+7 workspace number 7
          bindsym ${swayModifier}+8 workspace number 8
          bindsym ${swayModifier}+9 workspace number 9
          bindsym ${swayModifier}+Down focus down
          bindsym ${swayModifier}+Left focus left
          bindsym ${swayModifier}+Return exec alacritty
          bindsym ${swayModifier}+Right focus right
          bindsym ${swayModifier}+Shift+1 move container to workspace number 1
          bindsym ${swayModifier}+Shift+2 move container to workspace number 2
          bindsym ${swayModifier}+Shift+3 move container to workspace number 3
          bindsym ${swayModifier}+Shift+4 move container to workspace number 4
          bindsym ${swayModifier}+Shift+5 move container to workspace number 5
          bindsym ${swayModifier}+Shift+6 move container to workspace number 6
          bindsym ${swayModifier}+Shift+7 move container to workspace number 7
          bindsym ${swayModifier}+Shift+8 move container to workspace number 8
          bindsym ${swayModifier}+Shift+9 move container to workspace number 9
          bindsym ${swayModifier}+Shift+Down move down
          bindsym ${swayModifier}+Shift+Left move left
          bindsym ${swayModifier}+Shift+Right move right
          bindsym ${swayModifier}+Shift+Up move up
          bindsym ${swayModifier}+Shift+c reload
          bindsym ${swayModifier}+Shift+e exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -b 'Yes, exit sway' 'swaymsg exit'
          bindsym ${swayModifier}+Shift+h move left
          bindsym ${swayModifier}+Shift+j move down
          bindsym ${swayModifier}+Shift+k move up
          bindsym ${swayModifier}+Shift+l move right
          bindsym ${swayModifier}+Shift+minus move scratchpad
          bindsym ${swayModifier}+q kill
          bindsym ${swayModifier}+Shift+space floating toggle
          bindsym ${swayModifier}+Up focus up
          bindsym ${swayModifier}+a focus parent
          bindsym ${swayModifier}+b splith
          bindsym ${swayModifier}+e layout toggle split
          bindsym ${swayModifier}+f fullscreen toggle
          bindsym ${swayModifier}+h focus left
          bindsym ${swayModifier}+j focus down
          bindsym ${swayModifier}+k focus up
          bindsym ${swayModifier}+l focus right
          bindsym ${swayModifier}+minus scratchpad show
          bindsym ${swayModifier}+r mode resize
          bindsym ${swayModifier}+s layout stacking
          bindsym ${swayModifier}+v splitv
          bindsym ${swayModifier}+w layout tabbed

          # For resizing
          bindsym ${swayModifier}+Control+1 resize set width 10ppt
          bindsym ${swayModifier}+Control+2 resize set width 20ppt
          bindsym ${swayModifier}+Control+3 resize set width 30ppt
          bindsym ${swayModifier}+Control+4 resize set width 40ppt
          bindsym ${swayModifier}+Control+5 resize set width 50ppt
          bindsym ${swayModifier}+Control+6 resize set width 60ppt
          bindsym ${swayModifier}+Control+7 resize set width 70ppt
          bindsym ${swayModifier}+Control+8 resize set width 80ppt
          bindsym ${swayModifier}+Control+9 resize set width 90ppt

          # for launching applications
          bindsym ${swayModifier}+d exec wofi -H 800 -W 1800 --show drun

          # for moving the workspaces between monitors
          bindsym ${swayModifier}+Control+Shift+Up move workspace to output up
          bindsym ${swayModifier}+Control+Shift+Down move workspace to output down
          bindsym ${swayModifier}+Control+Shift+Left move workspace to output left
          bindsym ${swayModifier}+Control+Shift+Right move workspace to output right

          # for moving between workspaces quickly
          bindsym ${swayModifier}+Alt+p [app_id="org.keepassxc.KeePassXC"] focus
          bindsym ${swayModifier}+Alt+s [app_id="signal"] focus
          bindsym ${swayModifier}+Alt+l [app_id="Slack"] focus
          bindsym ${swayModifier}+Alt+e workspace editor
          bindsym ${swayModifier}+Alt+n workspace files
          bindsym ${swayModifier}+Alt+j workspace jetbrains
          bindsym ${swayModifier}+Alt+b [title="btop"] focus
          bindsym ${swayModifier}+Alt+f exec sway-switch-and-launch-if-ne browser firefox firefox
          bindsym ${swayModifier}+Alt+r exec sway-switch-and-launch-if-ne email firefox firefox --new-window https://fastmail.com
          bindsym ${swayModifier}+Alt+c exec sway-switch-and-launch-if-ne calendar firefox firefox --new-window https://calendar.google.com
          bindsym ${swayModifier}+Alt+o exec sway-switch-and-launch-if-ne obs obs obs
          bindsym ${swayModifier}+Alt+t workspace terminal
          bindsym ${swayModifier}+Alt+a workspace spotify

          # for moving workspaces to  monitors quickly
          bindsym ${swayModifier}+Alt+1 move workspace to output "${monitors.left}"
          bindsym ${swayModifier}+Alt+2 move workspace to output "${monitors.middle}"
          bindsym ${swayModifier}+Alt+3 move workspace to output "${monitors.right}"


          # for swapping between workspaces
          bindsym ${swayModifier}+space exec swayr switch-to-urgent-or-lru-window --skip-urgent
          bindsym ${swayModifier}+Alt+space exec swayr switch-to-urgent-or-lru-window --skip-lru
          bindsym ${swayModifier}+Shift+s exec swayr switch-window
          bindsym ${swayModifier}+Shift+w exec swayr switch-workspace
          bindsym ${swayModifier}+Shift+x exec swayr steal-window
          bindsym ${swayModifier}+Shift+z exec swayr move-focused-to-workspace

          bindsym ${swayModifier}+Shift+p exec swayr move-focused-to-workspace
          bindsym ${swayModifier}+Shift+q exec swayr quit-window

          # for locking the screen
          bindsym ${swayModifier}+grave exec swaylock

          # for toggling single monitor mode
          bindsym ${swayModifier}+Shift+f exec single-monitor-mode

          # for turning monitors on and off
          bindsym ${swayModifier}+Shift+o output * dpms off
          bindsym ${swayModifier}+Control+Shift+o output * dpms on

          exec swaymsg "workspace messages; exec slack;"
          exec swaymsf "workspace messages; exec signal-desktop;"
          exec swaymsg "workspace password; exec keepassxc"
          exec swaymsg "workspace editor; exec alacritty -t nvim"
          exec swaymsg "workspace monitoring; exec alacritty -t btop -e btop"
          exec swaymsg "workspace spotify; exec spotify"

          # Indicate to systemd that we have started the sway session
          exec sway-session-start --with-cleanup

          # make sway and gtk play nicely together (icons and themes)
          exec_always configure-gtk

          # start mako (notifications)
          exec_always mako-start
        '';
      };
  };

}
