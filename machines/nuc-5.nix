{ lib, ... }:
let
  disko = import ../lib/util/disko.nix;
in
{
  cpuVendor = "intel";
  cpuCount = 16;
  cpuArch = "x86-64-v3"; # Portable ISA level; arrowlake-specific scheduling via cpuTune
  cpuTune = "arrowlake";
  systemRam = 32;
  deviceType = "remote-builder";

  # CPU isolation: 2 P-cores for housekeeping, remaining 14 cores for builds
  # Intel Core Ultra 9 285H: 6 P-cores (0-5), 8 E-cores (6-13), 2 LP E-cores (14-15)
  # Housekeeping on P-cores 0-1 for OS responsiveness; builds on 2-15
  # Verify topology on first boot: lscpu -e
  builderHousekeepingCpus = "0-1";
  builderIsolatedCpus = "2-15";

  ######################################
  ## Networking
  ######################################
  networking = {
    hostName = "fullykubed-nuc-5";
    hostId = "b1495bae";
  };

  ######################################
  ## Disk Layout (disko)
  ######################################
  disko.devices.disk.main = {
    type = "disk";
    device = lib.mkDefault "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        boot1 = disko.mkBootPartition 1;
        boot2 = disko.mkBootPartition 2;
        swap1 = {
          size = "32G";
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
