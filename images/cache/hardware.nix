{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../builder/hardening.nix
  ];

  # Boot configuration for Hetzner Cloud (UEFI)
  boot = {
    loader = {
      efi.canTouchEfiVariables = false;
      timeout = 0;
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "nodev";
      };
    };

    initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_scsi"
      "virtio_blk"
      "virtio_net"
      "ahci"
      "sd_mod"
    ];

    kernelModules = [ "kvm-amd" ];

    # Serial console for Hetzner web console; quiet boot
    kernelParams = [
      "console=ttyS0,115200n8"
      "quiet"
      "loglevel=3"
    ];
  };

  # Network configuration - DHCP from Hetzner via networkd
  networking = {
    useDHCP = lib.mkDefault true;
  };
  systemd.network.enable = true;
  networking.useNetworkd = true;

  # Disk image size for nixos-generators
  # Larger than builders to accommodate PostgreSQL database
  virtualisation.diskSize = 80 * 1024; # 80GB in MB

  # Hardware-specific settings
  hardware.cpu.amd.updateMicrocode = true;
  nixpkgs.hostPlatform = "x86_64-linux";
}
