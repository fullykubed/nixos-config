{ lib, ... }:
let
  disko = import ../lib/util/disko.nix;
in
{
  cpuVendor = "amd";
  cpuCount = 64;
  cpuArch = "x86-64-v3"; # Portable ISA level; znver5-specific scheduling via cpuTune
  cpuTune = "znver5";
  systemRam = 256;
  deviceType = "remote-builder";

  # CPU isolation: CCD 0 for housekeeping, CCDs 1-7 for builds
  # Zen 5 9980X: 8 CCDs x 8 cores x 2 threads = 128 threads
  # CCD 0 = threads 0-15, CCD 1 = threads 16-31, ...
  # Aligning to CCD boundaries avoids L3 cache contention
  builderHousekeepingCpus = "0-15";
  builderIsolatedCpus = "16-127";

  ######################################
  ## Networking
  ######################################
  networking = {
    hostName = "fullykubed-threadripper-1";
    hostId = "5a39f3c2";
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
          size = "256G";
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
