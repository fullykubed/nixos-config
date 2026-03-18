{
  config,
  pkgs,
  lib,
  ...
}:
let
  batteryNotifyScript = pkgs.writeShellScript "battery-notify" ''
    STATE_FILE="$XDG_RUNTIME_DIR/battery-notify-state"

    # Get battery info from upower
    battery_info=$(${pkgs.upower}/bin/upower -i /org/freedesktop/UPower/devices/battery_BAT0)
    percentage=$(echo "$battery_info" | ${pkgs.gnugrep}/bin/grep -oP 'percentage:\s+\K\d+')
    state=$(echo "$battery_info" | ${pkgs.gnugrep}/bin/grep -oP 'state:\s+\K\w+')

    # Only warn when discharging
    [ "$state" != "discharging" ] && rm -f "$STATE_FILE" && exit 0

    last_warning=$(cat "$STATE_FILE" 2>/dev/null || echo "none")

    if [ "$percentage" -le 10 ] && [ "$last_warning" != "critical" ]; then
      ${pkgs.libnotify}/bin/notify-send --urgency=critical "Battery Critical" "Battery at ''${percentage}% — plug in now"
      echo "critical" > "$STATE_FILE"
    elif [ "$percentage" -le 20 ] && [ "$last_warning" = "none" ]; then
      ${pkgs.libnotify}/bin/notify-send --urgency=normal "Battery Low" "Battery at ''${percentage}%"
      echo "low" > "$STATE_FILE"
    fi
  '';
in
{
  config = lib.mkIf (config.deviceType == "laptop") {
    # Battery daemon with critical power action
    services.upower = {
      enable = true;
      usePercentageForPolicy = true;
      percentageLow = 20;
      percentageCritical = 10;
      percentageAction = 3;
      criticalPowerAction = "Suspend";
      allowRiskyCriticalPowerAction = true;
    };

    # Lightweight power optimizations at boot
    powerManagement.powertop.enable = true;

    # Battery level notification service (user-level for D-Bus access)
    home-manager.users.${config.username} = {
      systemd.user.services.battery-notify = {
        Unit = {
          Description = "Check battery level and send notifications";
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${batteryNotifyScript}";
          Environment = "DBUS_SESSION_BUS_ADDRESS=%t/bus";
        };
      };

      systemd.user.timers.battery-notify = {
        Unit = {
          Description = "Periodically check battery level";
        };
        Timer = {
          OnBootSec = "1min";
          OnUnitActiveSec = "2min";
        };
        Install = {
          WantedBy = [ "timers.target" ];
        };
      };
    };
  };
}
