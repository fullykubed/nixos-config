{
  config,
  lib,
  ...
}:
let
  # Find the monitor that should display notifications
  notificationMonitor = lib.findFirst (name: config.monitors.${name}.notifications or false) null (
    lib.attrNames config.monitors
  );
in
{
  home-manager.users.${config.username} = {
    # SwayNC configuration
    services.swaync = {
      enable = true;
      settings = {
        positionX = "right";
        positionY = "top";
        notification-window-preferred-output = notificationMonitor;
        control-center-preferred-output = notificationMonitor;
        layer = "overlay";
        control-center-layer = "top";
        layer-shell = true;
        cssPriority = "application";
        control-center-width = 500;
        control-center-height = 600;
        control-center-margin-top = 10;
        control-center-margin-bottom = 10;
        control-center-margin-right = 10;
        control-center-margin-left = 10;
        notification-2fa-action = true;
        notification-inline-replies = false;
        notification-icon-size = 64;
        notification-body-image-height = 100;
        notification-body-image-width = 200;
        timeout = 10;
        timeout-low = 5;
        timeout-critical = 0;
        fit-to-screen = true;
        control-center-exclusive-zone = true;
        notification-window-width = 500;
        keyboard-shortcuts = true;
        image-visibility = "when-available";
        transition-time = 200;
        hide-on-clear = false;
        hide-on-action = true;
        script-fail-notify = true;

        widgets = [
          "inhibitors"
          "title"
          "dnd"
          "notifications"
        ];

        # Notification visibility rules
        notification-visibility = {
          spotify = {
            state = "transient";
            app-name = "Spotify";
          };
          spotify-player = {
            state = "transient";
            app-name = "spotify_player";
          };
          spotify-tui = {
            state = "transient";
            app-name = "spotify-tui";
          };
        };

        widget-config = {
          inhibitors = {
            text = "Inhibitors";
            button-text = "Clear All";
            clear-all-button = true;
          };
          title = {
            text = "Notifications";
            clear-all-button = true;
            button-text = "Clear All";
          };
          dnd = {
            text = "Do Not Disturb";
          };
          label = {
            max-lines = 5;
            text = "Label Text";
          };
          mpris = {
            image-size = 96;
            image-radius = 12;
          };
        };
      };

      style = ''
        @define-color bg-color rgba(20, 40, 70, 0.9);
        @define-color fg-color rgb(255, 255, 255);
        @define-color border-color rgba(135, 206, 235, 0.2);
        @define-color hover-color rgba(135, 206, 235, 0.15);
        @define-color urgent-color rgb(255, 92, 87);
        @define-color blue rgb(135, 206, 235);
        @define-color pastel-red rgba(180, 60, 70, 0.9);

        * {
          font-family: "JetBrainsMono Nerd Font";
          font-weight: normal;
        }

        .notification-row {
          outline: none;
        }

        .notification-row:focus,
        .notification-row:hover {
          background: @hover-color;
        }

        .notification {
          border-radius: 12px;
          margin: 6px 12px;
          box-shadow: 0 0 0 1px @border-color;
          padding: 0;
        }

        .notification-content {
          background: transparent;
          padding: 12px;
          border-radius: 12px;
        }

        .close-button {
          background: @hover-color;
          color: @fg-color;
          text-shadow: none;
          padding: 0;
          border-radius: 100%;
          margin-top: 10px;
          margin-right: 10px;
          box-shadow: none;
          border: none;
          min-width: 24px;
          min-height: 24px;
        }

        .close-button:hover {
          box-shadow: none;
          background: @urgent-color;
          transition: all 0.15s ease-in-out;
          border: none;
        }

        .notification-default-action,
        .notification-action {
          padding: 4px;
          margin: 0;
          box-shadow: none;
          background: @bg-color;
          border: 1px solid @border-color;
          color: @fg-color;
          transition: all 0.15s ease-in-out;
        }

        .notification-default-action:hover,
        .notification-action:hover {
          -gtk-icon-effect: none;
          background: @hover-color;
        }

        .notification-default-action {
          border-radius: 12px;
        }

        .notification-default-action:not(:only-child) {
          border-bottom-left-radius: 0px;
          border-bottom-right-radius: 0px;
        }

        .notification-action {
          border-radius: 0px;
          border-top: none;
          border-right: none;
        }

        .notification-action:first-child {
          border-left: none;
          border-bottom-left-radius: 12px;
        }

        .notification-action:last-child {
          border-right: none;
          border-bottom-right-radius: 12px;
        }

        .notification-action:only-child {
          border-radius: 0;
        }

        .inline-reply {
          margin-top: 8px;
        }

        .inline-reply-entry {
          background: @bg-color;
          color: @fg-color;
          caret-color: @fg-color;
          border: 1px solid @border-color;
          border-radius: 12px;
        }

        .inline-reply-button {
          margin-left: 4px;
          background: @bg-color;
          border: 1px solid @border-color;
          border-radius: 12px;
          color: @fg-color;
        }

        .inline-reply-button:disabled {
          background: initial;
          color: @fg-color;
          border: 1px solid transparent;
        }

        .inline-reply-button:hover {
          background: @hover-color;
        }

        .summary {
          font-size: 16px;
          font-weight: bold;
          background: transparent;
          color: @fg-color;
          text-shadow: none;
        }

        .time {
          font-size: 12px;
          font-weight: normal;
          background: transparent;
          color: @fg-color;
          text-shadow: none;
          margin-right: 18px;
        }

        .body {
          font-size: 14px;
          font-weight: normal;
          background: transparent;
          color: @fg-color;
          text-shadow: none;
        }

        .control-center {
          background: @bg-color;
          border-radius: 12px;
          border: 1px solid @border-color;
        }

        .control-center-list {
          background: transparent;
        }

        .control-center-list-placeholder {
          opacity: 0.5;
        }

        .floating-notifications {
          background: transparent;
        }

        .blank-window {
          background: alpha(black, 0.1);
        }

        .widget-title {
          color: @fg-color;
          background: transparent;
          padding: 8px;
          margin: 8px;
          font-size: 16px;
          font-weight: bold;
        }

        .widget-title > button {
          font-size: 12px;
          color: @fg-color;
          text-shadow: none;
          background: @hover-color;
          border: 1px solid @border-color;
          box-shadow: none;
          border-radius: 12px;
          padding: 4px 8px;
        }

        .widget-title > button:hover {
          background: @blue;
        }

        .widget-dnd {
          background: transparent;
          padding: 8px;
          margin: 8px;
        }

        .widget-dnd > switch {
          font-size: 14px;
          background: @hover-color;
          border: 1px solid @border-color;
          box-shadow: none;
          border-radius: 12px;
        }

        .widget-dnd > switch:checked {
          background: @blue;
          border: 1px solid @blue;
        }

        .widget-dnd > switch slider {
          background: @fg-color;
          border-radius: 12px;
        }

        .widget-label {
          margin: 8px;
        }

        .widget-label > label {
          font-size: 14px;
          color: @fg-color;
        }

        .widget-mpris {
          color: @fg-color;
          background: @hover-color;
          padding: 8px;
          margin: 8px;
          border-radius: 12px;
        }

        .widget-mpris > box > button {
          border: none;
          background: transparent;
        }

        .widget-mpris-player {
          padding: 8px;
          margin: 8px;
        }

        .widget-mpris-title {
          font-weight: bold;
          font-size: 14px;
        }

        .widget-mpris-subtitle {
          font-size: 12px;
        }

        .widget-buttons-grid {
          padding: 8px;
          margin: 8px;
          border-radius: 12px;
          background: @hover-color;
        }

        .widget-buttons-grid > flowbox > flowboxchild > button {
          background: @bg-color;
          border-radius: 12px;
          border: 1px solid @border-color;
          margin: 3px;
        }

        .widget-buttons-grid > flowbox > flowboxchild > button:hover {
          background: @blue;
        }

        .widget-menubar > box > .menu-button-bar > button {
          border: none;
          background: transparent;
        }

        .widget-volume {
          background: @hover-color;
          padding: 8px;
          margin: 8px;
          border-radius: 12px;
        }

        .widget-volume > box > button {
          background: transparent;
          border: none;
        }

        .per-app-volume {
          background: @bg-color;
          padding: 4px 8px 8px 8px;
          margin: 0px 8px 8px 8px;
          border-radius: 12px;
        }

        .widget-backlight {
          background: @hover-color;
          padding: 8px;
          margin: 8px;
          border-radius: 12px;
        }

        .widget-inhibitors {
          margin: 8px;
          font-size: 14px;
        }

        .widget-inhibitors > button {
          font-size: 12px;
          color: @fg-color;
          text-shadow: none;
          background: @hover-color;
          border: 1px solid @border-color;
          box-shadow: none;
          border-radius: 12px;
          padding: 4px 8px;
        }

        .widget-inhibitors > button:hover {
          background: @urgent-color;
        }

        /* Critical notification styling */
        .notification.critical .notification-content {
          background: @pastel-red;
        }

        .notification.critical .notification-default-action {
          background: @pastel-red;
        }
      '';
    };
  };
}
