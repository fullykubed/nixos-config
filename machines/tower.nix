{ lib, ... }:
let
  disko = import ../lib/util/disko.nix;
in
{

  cpuVendor = "amd";
  cpuCount = 32;
  cpuArch = "x86-64-v3";
  cpuTune = "znver4";
  systemRam = 64;
  gpuVendor = "amd";
  deviceType = "desktop";
  disableWakeupTriggers = true;

  ######################################
  ## Networking
  ######################################
  networking = {
    hostName = "fullykubed-tower"; # Define your hostname.
    hostId = "925bf176";
  };

  ######################################
  ## Monitors
  ######################################
  monitors = {
    "DP-5" = {
      mode = "3840x2160";
      pos = "0 0";
      num = 1; # Left monitor
    };
    "DP-6" = {
      mode = "3840x2160";
      pos = "3840 0";
      num = 2; # Middle monitor
      notifications = true;
    };
    "DP-4" = {
      mode = "3840x2160";
      pos = "7680 0";
      num = 3; # Right monitor
    };
  };

  ######################################
  ## Disk Layout (disko)
  ######################################
  # NOTE: Tower EFI migration required - one-time manual step:
  #   Before this config will work, you must relabel the EFI partitions:
  #   1. Boot into live USB
  #   2. fatlabel /dev/disk/by-uuid/3103-B6F3 EFI_A
  #   3. fatlabel /dev/disk/by-uuid/3182-4B71 EFI_B
  #   4. Update fstab to use /boot1 and /boot2 mount points
  #   5. Rebuild with this config
  disko.devices.disk.main = {
    type = "disk";
    device = lib.mkDefault "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        boot1 = disko.mkBootPartition 1;
        boot2 = disko.mkBootPartition 2;
        swap1 = {
          size = "64G";
          content = {
            type = "swap";
            randomEncryption = true;
          };
        };
        swap2 = {
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
