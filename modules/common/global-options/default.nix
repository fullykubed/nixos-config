{
  config,
  lib,
  ...
}:
{
  options = with lib; {
    username = mkOption {
      type = types.str;
      description = "The primary user's username on the system.";
    };

    homeDir = mkOption {
      default = "/home/${config.username}";
      type = types.str;
      description = "The primary user's username on the system.";
    };

    deviceType = mkOption {
      type = types.enum [
        "laptop"
        "desktop"
        "server"
      ];
      description = "The type of device — controls power management and other hardware-class defaults.";
    };

    firmwareType = mkOption {
      type = types.enum [
        "standard"
        "coreboot"
      ];
      default = "standard";
      description = "Firmware type — 'coreboot' enables fwupd and flashrom for coreboot-based firmware updates.";
    };

    monitors = mkOption {
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            mode = mkOption {
              type = types.str;
              description = "Display mode (e.g., '3840x2160')";
            };
            pos = mkOption {
              type = types.str;
              description = "Position (e.g., '0 0', '3840 0')";
            };
            num = mkOption {
              type = types.int;
              description = "Monitor number (1=left, 2=middle, 3=right)";
            };
            notifications = mkOption {
              type = types.bool;
              default = false;
              description = "Whether this monitor should display notifications";
            };
          };
        }
      );
      description = "Monitor configuration where keys are output names and values contain mode, position, and number.";
    };
  };
}
