{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{

  # The linux kernl to use
  boot.kernelPackages = pkgs.linuxPackages_6_15;

  # These are kernel modules needed at stage 1 of the boot process
  boot.initrd.kernelModules = [
    "nvme" # NVME drives
    "xhci_pci" # USB 3.0
    "ahci" # SATA drives
    "usbhid" # USB HID devices
    "usb_storage" # USB storage devices
    "sd_mod" # SD card support
    "zfs" # ZFS support
  ];

  boot.kernelModules = [
    # Monitoring device sensors
    "k10temp"
    "nct6775"
    "i2c-piix4"
    "lm92"
  ];

  boot.kernel.sysctl = {
    # See https://github.com/k3d-io/k3d/issues/116
    "fs.inotify.max_user_instances" = 1280;
    "fs.inotify.max_user_watches" = 655360;

    # Allow OOM watching
    "kernel.dmesg_restrict" = 0;
  };

  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    efi = {
      efiSysMountPoint = "/boot";
      canTouchEfiVariables = true;
    };
  };
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };

  # Copies the EFI partition to a backup partition. This allows us to boot even if the first
  # drive becomes corrupted.
  system.activationScripts = {
    boot-sync.text = "${pkgs.rsync}/bin/rsync -avq --delete /boot/ /boot1/";
  };

  boot.kernelParams = [
    "amdgpu.ras_enable=0" # disable RAS which was causing hw errors with the W6800 gpu
    "acpi_enforce_resources=lax" # allows for hardware sensors from the motherboard to appear
  ];

  environment.systemPackages = with pkgs; [
    tpm2-tools
    tpm2-abrmd
    efibootmgr
    efitools
    sbctl # secure boot key manager
  ];

}
