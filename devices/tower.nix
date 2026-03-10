_:

{

  cpuVendor = "amd";
  gpuVendor = "amd";
  disableWakeupTriggers = true;

  # Enable thermal monitoring
  environment.etc."sysconfig/lm_sensors".text = ''
    HWMON_MODULES="k10temp nct6775 i2c-piix4 lm92"
  '';

  ######################################
  ## Networking
  ######################################
  networking = {
    hostName = "fullykubed-tower"; # Define your hostname.
    hostId = "925bf176";
    interfaces.enp75s0.useDHCP = true;
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
  ## Boot Settings
  ######################################
  boot.zfs = {
    requestEncryptionCredentials = [
      "primary/nixos"
    ];
    # TODO: Re-evaluate this
    forceImportAll = false;
  };

  ######################################
  ## Filesystem
  ######################################
  fileSystems = {
    "/" = {
      device = "primary/nixos/root";
      fsType = "zfs";
    };

    "/home" = {
      device = "primary/nixos/home";
      fsType = "zfs";
    };

    "/nix/store" = {
      device = "primary/nixos/nix-store";
      fsType = "zfs";
    };

    "/nix/var/nix/db" = {
      device = "primary/nixos/nix-db";
      fsType = "zfs";
    };

    "/tmp" = {
      device = "primary/nixos/tmp";
      fsType = "zfs";
    };

    # We set "nofail" for the boot drives, b/c we don't want a drive failure to prevent
    # us from booting.
    "/boot" = {
      device = "/dev/disk/by-uuid/3103-B6F3";
      fsType = "vfat";
      options = [ "nofail" ];
    };

    "/boot1" = {
      device = "/dev/disk/by-uuid/3182-4B71";
      fsType = "vfat";
      options = [ "nofail" ];
    };
  };

  # Again, "nofail" as these are not critical
  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/5c7ca6b5-ddd8-9442-b94e-e3eb55d8ca20";
      randomEncryption = true;
      options = [ "nofail" ];
    }
    {
      device = "/dev/disk/by-partuuid/5ad84ba3-013c-084b-9685-02f979ac5dd0";
      randomEncryption = true;
      options = [ "nofail" ];
    }
  ];

  ######################################
  ## Misc Hardware Settings
  ######################################
  powerManagement.cpuFreqGovernor = "performance";

  cpuCount = 32;
}
