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
    ../modules/utility/intel-cpu.nix
  ];

  # Enable thermal monitoring
  environment.etc."sysconfig/lm_sensors".text = ''
    HWMON_MODULES="k10temp nct6775 i2c-piix4 lm92"
  '';

  ######################################
  ## Networking
  ######################################
  networking.hostName = "fullykubed-mini-pc"; # Define your hostname.
  networking.hostId = "925bf177";
  networking.interfaces.enp87s0.useDHCP = true;

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
    "rpool"
  ];
  # TODO: Re-evaluate this
  boot.zfs.forceImportAll = false;

  ######################################
  ## Filesystem
  ######################################
  fileSystems."/" = {
    device = "rpool/root";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "rpool/home";
    fsType = "zfs";
  };

  fileSystems."/nix" = {
    device = "rpool/nix";
    fsType = "zfs";
  };

  fileSystems."/var/log" = {
    device = "rpool/var/log";
    fsType = "zfs";
  };

  fileSystems."/tmp" = {
    device = "rpool/tmp";
    fsType = "zfs";
  };

  # We set "nofail" for the boot drives, b/c we don't want a drive failure to prevent
  # us from booting.
  fileSystems."/boot1" = {
    device = "/dev/disk/by-label/EFI_A";
    fsType = "vfat";
    options = [ "nofail" ];
  };

  fileSystems."/boot2" = {
    device = "/dev/disk/by-label/EFI_B";
    fsType = "vfat";
    options = [ "nofail" ];
  };

  ######################################
  ## Misc Hardware Settings
  ######################################
  powerManagement.cpuFreqGovernor = "performance";
}
