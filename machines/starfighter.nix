{
  lib,
  modulesPath,
  ...
}:
let
  disko = import ../lib/util/disko.nix;
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  cpuVendor = "intel";
  cpuCount = 16;
  cpuArch = "x86-64-v3";
  cpuTune = "arrowlake";
  systemRam = 64;
  deviceType = "laptop";
  firmwareType = "coreboot";

  ######################################
  ## Networking
  ######################################
  networking = {
    hostName = "fullykubed-starfighter";
    hostId = "06450bf0";
  };

  ######################################
  ## Monitors
  ######################################
  monitors = {
    "eDP-1" = {
      mode = "3840x2400";
      pos = "0 0";
      scale = 1.25;
      num = 1;
      notifications = true;
    };
  };

  ######################################
  ## Filesystem
  ######################################
  disko.devices.disk.main = {
    type = "disk";
    device = lib.mkDefault "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        boot = disko.mkBootPartition 1;
        swap = {
          size = "64G";
          content = {
            type = "swap";
            randomEncryption = true;
          };
        };
        zfs = {
          size = "100%";
          content = {
            type = "zfs";
            pool = "rpool";
          };
        };
      };
    };
  };
}
