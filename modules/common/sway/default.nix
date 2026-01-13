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

  # Helper function to get monitor name by number
  getMonitorByNum =
    num:
    let
      monitorList = lib.attrValues (
        lib.mapAttrs (name: value: { inherit name; } // value) config.monitors
      );
      monitor = lib.findFirst (m: m.num == num) null monitorList;
    in
    if monitor != null then monitor.name else "";
in
{
  imports = [
    ./copyq
    ./swaync.nix
    ./swayidle.nix
    ./waybar
  ];

  # enable sway window manager
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      swaytools # tooling to help debug and setup sway
      swaylock # sway lock screen
      swayidle # sway idle timer
      waybar # status bar
      wlprop # window property displayer
      unstable.swayr # window switcher
      wl-clipboard
      wf-recorder
      swaynotificationcenter # notification daemon with control center
      libnotify # for scripting notifications
      sway-contrib.grimshot # screenshot tool
      grim # screenshot utility
      slurp # region selection utility
      satty # screenshot annotation tool
      imagemagick # for image conversion in screenshot script
      xdg-utils # for opening default programs when clicking links
      glib # gsettings
      dracula-theme # gtk theme
      wofi # menu / launcher
      ydotool # scripting CLI for wayland
      wl-color-picker # color picker for wayland

      # Custom sway scripts
      scripts
      configure-gtk
    ];
  };

  environment.sessionVariables = {
    # Used for the notifications daemon settings
    SWAY_NOTIFICATION_OUTPUT = getMonitorByNum 2; # Middle monitor
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
      # Sets up wofi
      "wofi/config" = {
        text = ''
          show=drun
          drun-display_generic=true
        '';
      };
    };

    programs.zsh = {
      # Make sure the desktop entries show up in sway
      profileExtra = ''
        if [ "$(tty)" = "/dev/tty1" ]; then
          export XDG_CURRENT_DESKTOP=sway
          exec systemd-cat -t sway sway
        fi
      '';
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
          terminal = "wezterm";
          menu = "wofi";
          gaps = {
            inner = 10;
          };
          window = {
            border = 5;
          };

          # Configure outputs from the monitors option
          output = lib.mapAttrs (_: value: {
            inherit (value) mode pos;
          }) config.monitors;

          # Handle the keybinds below for more flexibilitiy
          keybindings = { };

          bars = [ ]; # waybar runs as systemd user service
        };

        extraConfig = ''
          # floating windows
          for_window [title="fzf-switcher"] floating enable
          for_window [title="Firefox — Sharing Indicator"] floating enable
          for_window [app_id="com.github.hluk.copyq"] floating enable, resize set 50 ppt 50 ppt
          for_window [class="copyq"] floating enable, resize set 50 ppt 50 ppt
          for_window [title="CopyQ"] floating enable, resize set 50 ppt 50 ppt
          for_window [app_id="floating-terminal"] floating enable, resize set 50 ppt 50 ppt

          # Focus navigation
          bindsym ${swayModifier}+Alt+Up focus up
          bindsym ${swayModifier}+Alt+Down focus down
          bindsym ${swayModifier}+Alt+Left focus left
          bindsym ${swayModifier}+Alt+Right focus right
          bindsym ${swayModifier}+Alt+h focus left
          bindsym ${swayModifier}+Alt+j focus down
          bindsym ${swayModifier}+Alt+k focus up
          bindsym ${swayModifier}+Alt+l focus right

          # Quick application/workspace focus
          bindsym ${swayModifier}+Alt+p [app_id="org.keepassxc.KeePassXC"] focus
          bindsym ${swayModifier}+Alt+s [app_id="signal"] focus
          bindsym ${swayModifier}+Alt+m [app_id="Slack"] focus
          bindsym ${swayModifier}+Alt+e workspace editor
          bindsym ${swayModifier}+Alt+n workspace files
          bindsym ${swayModifier}+Alt+b [app_id="btop"] focus
          bindsym ${swayModifier}+Alt+f exec sway-switch-and-launch-if-ne browser firefox firefox
          bindsym ${swayModifier}+Alt+r exec sway-switch-and-launch-if-ne email firefox firefox --new-window https://fastmail.com
          bindsym ${swayModifier}+Alt+c exec sway-switch-and-launch-if-ne calendar firefox firefox --new-window https://calendar.google.com
          bindsym ${swayModifier}+Alt+o exec sway-switch-and-launch-if-ne obs obs obs
          bindsym ${swayModifier}+Alt+t workspace terminal
          bindsym ${swayModifier}+Alt+a workspace spotify

          # Swayr window/workspace switching
          bindsym ${swayModifier}+space exec swayr switch-to-urgent-or-lru-window --skip-urgent
          bindsym ${swayModifier}+Alt+space exec swayr switch-to-urgent-or-lru-window --skip-lru
          bindsym ${swayModifier}+Alt+w exec swayr switch-window
          bindsym ${swayModifier}+Alt+z exec swayr switch-workspace

          # Workspace navigation
          bindsym ${swayModifier}+Alt+1 workspace number 1
          bindsym ${swayModifier}+Alt+2 workspace number 2
          bindsym ${swayModifier}+Alt+3 workspace number 3
          bindsym ${swayModifier}+Alt+4 workspace number 4
          bindsym ${swayModifier}+Alt+5 workspace number 5
          bindsym ${swayModifier}+Alt+6 workspace number 6
          bindsym ${swayModifier}+Alt+7 workspace number 7
          bindsym ${swayModifier}+Alt+8 workspace number 8
          bindsym ${swayModifier}+Alt+9 workspace number 9

          # Rename current workspace
          bindsym ${swayModifier}+Shift+r exec echo "" | ${pkgs.wofi}/bin/wofi --show dmenu -p "Rename workspace to:" | xargs swaymsg rename workspace to

          # Window management
          bindsym ${swayModifier}+q kill
          bindsym ${swayModifier}+Shift+q exec swayr quit-window
          bindsym ${swayModifier}+f fullscreen toggle
          bindsym ${swayModifier}+Shift+space floating toggle
          bindsym ${swayModifier}+Shift+minus move scratchpad
          bindsym ${swayModifier}+minus scratchpad show

          # Layout management
          bindsym ${swayModifier}+b splith
          bindsym ${swayModifier}+v splitv
          bindsym ${swayModifier}+t layout stacking
          bindsym ${swayModifier}+w layout tabbed
          bindsym ${swayModifier}+e layout toggle split

          # System control
          bindsym ${swayModifier}+Shift+c reload
          bindsym ${swayModifier}+Shift+e exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -b 'Yes, exit sway' 'swaymsg exit'

          # Terminal
          bindsym ${swayModifier}+Return exec wezterm
          bindsym ${swayModifier}+Shift+Return exec wezterm start --class floating-terminal
          bindsym ${swayModifier}+o exec wezterm start -- bash -c "sesh connect \$(sesh list -t | ${pkgs.wofi}/bin/wofi --show dmenu -p 'Select tmux session:')"

          # Mode switching
          bindsym ${swayModifier}+r mode resize
          bindsym ${swayModifier}+XF86AudioMicMute mode "move-workspace"
          bindsym ${swayModifier}+XF86TouchpadToggle mode "move-window"

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

          # Move workspace mode
          mode "move-workspace" {
            # Move workspace to specific outputs
            bindsym 1 move workspace to output "${getMonitorByNum 1}"; mode "default"
            bindsym 2 move workspace to output "${getMonitorByNum 2}"; mode "default"
            bindsym 3 move workspace to output "${getMonitorByNum 3}"; mode "default"
            
            # Move workspace directionally (stay in mode)
            bindsym Up move workspace to output up
            bindsym Down move workspace to output down
            bindsym Left move workspace to output left
            bindsym Right move workspace to output right
            
            bindsym h move workspace to output left
            bindsym j move workspace to output down
            bindsym k move workspace to output up
            bindsym l move workspace to output right
            
            # Return to default mode
            bindsym Return mode "default"
            bindsym Escape mode "default"
            bindsym ${swayModifier}+XF86AudioMicMute mode "default"
          }

          # Move window mode
          mode "move-window" {
            # Move container to specific workspace numbers
            bindsym 1 move container to workspace number 1; mode "default"
            bindsym 2 move container to workspace number 2; mode "default"
            bindsym 3 move container to workspace number 3; mode "default"
            bindsym 4 move container to workspace number 4; mode "default"
            bindsym 5 move container to workspace number 5; mode "default"
            bindsym 6 move container to workspace number 6; mode "default"
            bindsym 7 move container to workspace number 7; mode "default"
            bindsym 8 move container to workspace number 8; mode "default"
            bindsym 9 move container to workspace number 9; mode "default"
            
            # Move container directionally (stay in mode)
            bindsym Up move up
            bindsym Down move down
            bindsym Left move left
            bindsym Right move right
            
            bindsym h move left
            bindsym j move down
            bindsym k move up
            bindsym l move right
            
            # Swayr commands
            bindsym s exec swayr steal-window; mode "default"
            bindsym m exec swayr move-focused-to-workspace; mode "default"
            
            # Return to default mode
            bindsym Return mode "default"
            bindsym Escape mode "default"
            bindsym ${swayModifier}+XF86TouchpadToggle mode "default"
          }

          # SwayNC notification center keybindings
          bindsym ${swayModifier}+n exec swaync-client -t -sw
          bindsym ${swayModifier}+Shift+Ctrl+Alt+d exec swaync-client -d -sw
          bindsym ${swayModifier}+Shift+Ctrl+Alt+c exec swaync-client -C -sw

          # Application launchers
          bindsym ${swayModifier}+d exec wofi
          bindsym ${swayModifier}+c exec ${pkgs.copyq}/bin/copyq toggle
          bindsym ${swayModifier}+p exec ${pkgs.wl-color-picker}/bin/wl-color-picker

          # Screenshot
          bindsym ${swayModifier}+s exec grimshot copy area
          bindsym ${swayModifier}+Shift+s exec screenshot-satty

          # for locking the screen (Hyper+L = Mod4+Shift+Control+Alt+L)
          bindsym ${swayModifier}+Shift+Control+Alt+l exec swaylock --color 000000 -fF

          # for suspending the system (Hyper+S = Mod4+Shift+Control+Alt+S)
          bindsym ${swayModifier}+Shift+Control+Alt+s exec ${pkgs.systemd}/bin/systemctl suspend

          # for toggling single monitor mode 
          bindsym ${swayModifier}+Shift+Control+Alt+f exec single-monitor-mode

          # for turning monitors on and off
          bindsym ${swayModifier}+Shift+o output * dpms off
          bindsym ${swayModifier}+Control+Shift+o output * dpms on

          # Volume control keybindings
          bindsym XF86AudioRaiseVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
          bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
          bindsym XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
          bindsym XF86AudioMicMute exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

          # Media playback control keybindings
          bindsym XF86AudioPlay exec playerctl play-pause
          bindsym XF86AudioPause exec playerctl play-pause
          bindsym XF86AudioNext exec playerctl next
          bindsym XF86AudioPrev exec playerctl previous
          bindsym XF86AudioStop exec playerctl stop

          # Push-to-talk voice transcription
          bindsym --no-repeat F10 exec voxtype record start
          bindsym --release F10 exec voxtype record stop

          exec swaymsg "workspace messages; exec slack;"
          exec swaymsg "workspace messages; exec signal-desktop;"
          exec swaymsg "workspace password; exec keepassxc"
          exec swaymsg "workspace monitoring; exec wezterm start --class btop -- btop"
          exec swaymsg "workspace spotify; exec spotify"

          # Indicate to systemd that we have started the sway session
          exec sway-session-start --with-cleanup

          # make sway and gtk play nicely together (icons and themes)
          exec_always configure-gtk

          # start swaync (notification center)
          exec_always swaync
        '';
      };
  };

}
