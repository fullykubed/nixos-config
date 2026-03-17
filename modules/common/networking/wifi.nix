{
  config,
  lib,
  pkgs,
  ...
}:
let
  wifiDir = ../../../secrets/wifi;
  wifiNetworks =
    if builtins.pathExists wifiDir then
      lib.mapAttrsToList (name: _: lib.removeSuffix ".age" name) (
        lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".age" name) (
          builtins.readDir wifiDir
        )
      )
    else
      [ ];
  hasNetworks = wifiNetworks != [ ];
in
{
  options.hasWifi = lib.mkOption {
    type = lib.types.bool;
    default = config.deviceType == "laptop";
    description = "Whether this machine has a WiFi adapter. Defaults to true for laptops.";
  };

  config = lib.mkIf config.hasWifi (
    lib.mkMerge [
      {
        networking.wireless.iwd = {
          enable = true;
          settings = {
            Settings.AutoConnect = true;
          };
        };

        networking.networkmanager.wifi.backend = "iwd";

        environment.systemPackages = [ pkgs.impala ];
      }

      (lib.mkIf hasNetworks {
        age.secrets = builtins.listToAttrs (
          map (ssid: {
            name = "wifi-${ssid}";
            value = {
              rekeyFile = ../../../secrets/wifi/${ssid}.age;
              mode = "0400";
              owner = "root";
            };
          }) wifiNetworks
        );

        systemd.services.wifi-profiles = {
          description = "Generate iwd WiFi profiles from agenix secrets";
          wantedBy = [ "multi-user.target" ];
          before = [ "iwd.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = lib.concatMapStringsSep "\n" (ssid: ''
            mkdir -p /var/lib/iwd
            cat > "/var/lib/iwd/${ssid}.psk" <<EOF
            [Settings]
            AutoConnect=true

            [Security]
            Passphrase=$(cat ${config.age.secrets."wifi-${ssid}".path})
            EOF
            chmod 0600 "/var/lib/iwd/${ssid}.psk"
          '') wifiNetworks;
        };
      })
    ]
  );
}
