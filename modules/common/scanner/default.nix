{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.versions = {
    brscan5 = lib.mkOption {
      type = lib.types.str;
      description = "Version of Brother brscan5 scanner driver";
    };
    brscan5Hash = lib.mkOption {
      type = lib.types.str;
      description = "Hash for brscan5 deb package";
    };
  };

  config =
    let
      inherit (config) versions;
    in
    lib.mkIf (config.deviceType != "remote-builder") {
      nixpkgs.overlays = [
        (_: prev: {
          brscan5 = prev.brscan5.overrideAttrs (_: {
            version = versions.brscan5;
            src = prev.fetchurl {
              url = "https://download.brother.com/welcome/dlf104033/brscan5-${versions.brscan5}.amd64.deb";
              hash = versions.brscan5Hash;
            };
          });
        })
      ];

      hardware.sane = {
        enable = true;
        brscan5.enable = true;
      };

      services = {
        saned.enable = true;
        avahi = {
          enable = true;
          nssmdns4 = true;
        };
      };

      environment.systemPackages = with pkgs; [
        naps2
      ];
    };
}
