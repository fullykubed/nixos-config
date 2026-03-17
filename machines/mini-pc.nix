{ lib, ... }:
let
  disko = import ../lib/util/disko.nix;
in
{

  cpuVendor = "intel";
  cpuCount = 16;
  deviceType = "desktop";

  ######################################
  ## Networking
  ######################################
  networking = {
    hostName = "fullykubed-mini-pc";
    hostId = "925bf177";
    interfaces.enp87s0.useDHCP = true;
  };

  ######################################
  ## Monitors
  ######################################
  monitors = {
    "HDMI-A-2" = {
      mode = "3840x2160";
      pos = "0 0";
      num = 1; # Left monitor
    };
    "DP-3" = {
      mode = "3840x2160";
      pos = "7680 0";
      num = 3; # Right monitor
    };
    "HDMI-A-1" = {
      mode = "3840x2160";
      pos = "3840 0";
      num = 2; # Middle monitor
      notifications = true;
    };
  };

  ######################################
  ## Filesystem
  ######################################
  # Two NVMe drives in a ZFS mirror, each with its own EFI partition.
  # No swap partitions — uses zram.
  disko.devices = {
    disk.nvme0 = {
      type = "disk";
      device = lib.mkDefault "/dev/nvme0n1";
      content = {
        type = "gpt";
        partitions = {
          boot = disko.mkBootPartition 1;
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
    disk.nvme1 = {
      type = "disk";
      device = lib.mkDefault "/dev/nvme1n1";
      content = {
        type = "gpt";
        partitions = {
          boot = disko.mkBootPartition 2;
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
    zpool.rpool.mode = "mirror";
  };
}
