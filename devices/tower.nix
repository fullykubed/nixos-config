{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../modules/utility/disable-wakeup-triggers.nix
    ../modules/utility/amd-cpu.nix
    ../modules/utility/amd-gpu.nix
  ];

  # Enable thermal monitoring
  environment.etc."sysconfig/lm_sensors".text = ''
    HWMON_MODULES="k10temp nct6775 i2c-piix4 lm92"
  '';

  ######################################
  ## Networking
  ######################################
  networking.hostName = "fullykubed-tower"; # Define your hostname.
  networking.hostId = "925bf176";
  networking.interfaces.enp75s0.useDHCP = true;

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
  ## Scanner
  ######################################
  # Scanning driver for Brother scanners (brother no longer provides the default version in nixpkgs)
  nixpkgs.overlays = [ (self: super: { brscan5 = pkgs.unstable.brscan5; }) ];
  hardware.sane = {
    enable = true;
    brscan5.enable = true;
  };
  services.saned.enable = true;
  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;

  ######################################
  ## Boot Settings
  ######################################
  boot.zfs.requestEncryptionCredentials = [
    "primary/nixos"
  ];
  # TODO: Re-evaluate this
  boot.zfs.forceImportAll = false;

  ######################################
  ## Filesystem
  ######################################
  fileSystems."/" = {
    device = "primary/nixos/root";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "primary/nixos/home";
    fsType = "zfs";
  };

  fileSystems."/nix/store" = {
    device = "primary/nixos/nix-store";
    fsType = "zfs";
  };

  fileSystems."/nix/var/nix/db" = {
    device = "primary/nixos/nix-db";
    fsType = "zfs";
  };

  fileSystems."/tmp" = {
    device = "primary/nixos/tmp";
    fsType = "zfs";
  };

  #  fileSystems."${config.homeDir}/media" =
  #    {
  #      device = "secondary/encrypted/media";
  #      fsType = "zfs";
  #    };

  #  fileSystems."/nix/var/log" =
  #    {
  #      device = "secondary/encrypted/logs/nix";
  #      fsType = "zfs";
  #    };

  # We set "nofail" for the boot drives, b/c we don't want a drive failure to prevent
  # us from booting.
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/3103-B6F3";
    fsType = "vfat";
    options = [ "nofail" ];
  };

  fileSystems."/boot1" = {
    device = "/dev/disk/by-uuid/3182-4B71";
    fsType = "vfat";
    options = [ "nofail" ];
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
}
