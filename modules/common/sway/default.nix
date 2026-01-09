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
    ./swaync.nix
    ./swayidle.nix
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

    # CopyQ clipboard manager
    services.copyq = {
      enable = true;
      systemdTarget = "sway-session.target";
    };

    xdg.configFile = {

      # Sets up waybar
      "waybar/config" = {
        source = ./waybar/config.json;
      };

      # Sets up wofi
      "wofi/config" = {
        text = ''
          show=drun
          drun-display_generic=true
        '';
      };

      # CopyQ configuration with dark theme
      "copyq/copyq.conf" = {
        text = ''
          [General]
          autostart=true
          check_clipboard=true
          check_selection=true
          clipboard_notification_lines=0
          clipboard_tab=&clipboard
          close_on_unfocus=true
          command_history_size=100
          confirm_exit=false
          copy_clipboard=true
          copy_selection=true
          disable_tray=false
          edit_ctrl_return=true
          editor=nvim
          expire_tab=0
          hide_main_window=true
          hide_main_window_in_task_bar=false
          hide_tabs=false
          hide_toolbar=false
          hide_toolbar_labels=true
          item_popup_interval=0
          language=en
          max_process_manager_rows=1000
          maxitems=200
          move=true
          native_menu_bar=true
          notification_horizontal_offset=10
          notification_maximum_height=100
          notification_maximum_width=300
          notification_position=3
          notification_vertical_offset=10
          number_search=true
          open_windows_on_current_screen=true
          run_selection=true
          save_delay_ms_on_item_added=300000
          save_delay_ms_on_item_edited=1000
          save_delay_ms_on_item_modified=300000
          save_delay_ms_on_item_moved=1800000
          save_delay_ms_on_item_removed=600000
          save_filter_history=false
          save_on_app_deactivated=true
          script_paste_delay_ms=250
          show_advanced_command_settings=false
          show_simple_items=false
          show_tab_item_count=false
          style=
          tab_icon_size=16
          tab_tree=false
          tabs=&clipboard
          text_tab_width=8
          text_wrap=true
          transparency=0
          transparency_focused=0
          tray_commands=true
          tray_images=true
          tray_item_paste=true
          tray_items=5
          tray_menu_open_on_left_click=false
          tray_tab_is_current=true
          vi=true
          window_wait_after_raised_ms=50
          window_wait_before_raise_ms=250
          window_wait_for_modifier_released_ms=2000
          window_wait_raised_ms=150

          [Plugins]
          itemencrypted\enabled=true
          itemfakevim\enabled=true
          itemimage\enabled=true
          itemimage\image_editor=
          itemimage\max_image_height=240
          itemimage\max_image_width=320
          itemimage\svg_editor=
          itemnotes\enabled=true
          itempinned\enabled=true
          itemsync\enabled=true
          itemtags\enabled=true
          itemtext\enabled=true

          [Shortcuts]
          about=shift+f1
          change_tab_icon=ctrl+shift+t
          clipboard_tab=
          commands=f6
          copy_selected_items=ctrl+c
          delete_item=del
          edit=f2
          edit_notes=shift+f2
          editor=ctrl+e
          exit=ctrl+q
          export=ctrl+s
          find_items=f3
          format-next=ctrl+right
          format-previous=ctrl+left
          help=f1
          import=ctrl+i
          item-menu=shift+f10
          move_down=ctrl+down
          move_to_bottom=ctrl+end
          move_to_clipboard=
          move_to_top=ctrl+home
          move_up=ctrl+up
          new=ctrl+n
          new_tab=ctrl+t
          next_tab=right
          paste_selected_items=ctrl+v
          preferences=ctrl+p
          previous_tab=left
          process_manager=ctrl+shift+z
          remove_tab=ctrl+w
          rename_tab=ctrl+f2
          reverse=ctrl+shift+r
          show-log=f12
          show_clipboard_content=ctrl+shift+c
          show_item_content=f4
          show_item_preview=f7
          sort_selected_items=ctrl+shift+s
          system-run=f5
          toggle_clipboard_storing=ctrl+shift+x

          [Tabs]
          1\icon=
          1\max_item_count=0
          1\name=&clipboard
          1\store_items=true
          size=1

          [Theme]
          alt_bg=#383838
          alt_item_css=
          bg=#2b2b2b
          css=
          css_template_items=items
          css_template_main_window=main_window
          css_template_menu=menu
          css_template_notification=notification
          cur_item_css=
          edit_bg=#2b2b2b
          edit_fg=#ffffff
          edit_font=
          fg=#dfdfdf
          find_bg=#ff6b00
          find_fg=#000000
          find_font=
          font=
          font_antialiasing=true
          hover_item_css=
          icon_size=16
          item_css=
          item_spacing=
          menu_bar_css=
          menu_bar_disabled_css=
          menu_bar_selected_css=
          menu_css=
          notes_bg=#2b2b2b
          notes_css=
          notes_fg=#dfdfdf
          notes_font=
          notification_bg=#2b2b2b
          notification_fg=#dfdfdf
          notification_font=
          num_fg=#7f7f7f
          num_font=
          num_margin=2
          search_bar=
          search_bar_focused=
          sel_bg=#666666
          sel_fg=#dfdfdf
          sel_item_css=
          show_number=true
          show_scrollbars=true
          style_main_window=false
          tab_bar_css=
          tab_bar_item_counter=
          tab_bar_scroll_buttons_css=
          tab_bar_sel_item_counter=
          tab_bar_tab_selected_css=
          tab_bar_tab_unselected_css=
          tab_tree_css=
          tab_tree_item_counter=
          tab_tree_sel_item_counter=
          tool_bar_css=
          tool_button_css=
          tool_button_pressed_css=
          tool_button_selected_css=
          use_system_icons=false
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
          output = lib.mapAttrs (name: value: {
            mode = value.mode;
            pos = value.pos;
          }) config.monitors;

          # Handle the keybinds below for more flexibilitiy
          keybindings = { };

          bars = [ { command = "${pkgs.waybar}/bin/waybar"; } ];
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
