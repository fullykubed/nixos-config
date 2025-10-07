{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{

  # The linux kernl to use
  boot.kernelPackages = pkgs.linuxPackages_6_16;

  # Use scudo memory allocator for improved security with better compatibility
  # Options: "libc" (default), "graphene-hardened", "graphene-hardened-light", "scudo", "jemalloc", "mimalloc"
  environment.memoryAllocator.provider = "graphene-hardened";

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
    "jitterentropy_rng"
  ];

  # Get extra entropy since we disabled hardware entropy sources
  # Read more about why at the following URLs:
  # https://github.com/smuellerDD/jitterentropy-rngd/issues/27
  # https://blogs.oracle.com/linux/post/rngd1
  services.jitterentropy-rngd.enable = true;

  boot.kernel.sysctl = {
    # See https://github.com/k3d-io/k3d/issues/116
    "fs.inotify.max_user_instances" = 1280;
    "fs.inotify.max_user_watches" = 655360;

    # Allow OOM watching
    "kernel.dmesg_restrict" = 0;
  };

  # Don't store coredumps from systemd-coredump.
  systemd.coredump.extraConfig = ''
    Storage=none
  '';

  # zram allows swapping to RAM by compressing memory. This reduces the chance
  # that sensitive data is written to disk, and eliminates it if zram is used
  # to completely replace swap to disk. Generally *improves* storage lifespan
  # and performance, there usually isn't a need to disable this.
  zramSwap.enable = true;

  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    efi = {
      efiSysMountPoint = "/boot1";
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
    boot-sync.text = "${pkgs.rsync}/bin/rsync -avq --delete /boot1/ /boot2/";
  };

  boot.kernelParams = [
    # GPU/Graphics related
    "amdgpu.ras_enable=0" # Disable RAS (Reliability, Availability, Serviceability) - was causing hardware errors with W6800 GPU
    "acpi_enforce_resources=lax" # Allow hardware sensors from motherboard to appear by relaxing ACPI resource conflict checking
    "i915.enable_psr=0" # Disable Panel Self Refresh on Intel iGPUs - fixes stuttering issues

    # Memory security hardening
    "slab_nomerge" # Disable merging of slab caches - prevents heap overflow attacks across different object types
    "init_on_alloc=1" # Zero-initialize memory on allocation - prevents information leaks
    "init_on_free=1" # Zero memory on free - prevents use-after-free data leaks
    "page_alloc.shuffle=1" # Randomize page allocator freelists - makes heap exploits harder
    "randomize_kstack_offset=on" # Randomize kernel stack offset on syscall entry - prevents stack-based attacks

    # System call and debugging restrictions
    "vsyscall=none" # Disable legacy vsyscall interface - removes fixed-address attack surface
    "debugfs=off" # Disable debugfs - prevents exposure of sensitive kernel information
    "oops=panic" # Panic on oops instead of continuing - prevents system from running in undefined state

    # Boot verbosity
    "quiet" # Suppress most boot messages
    "loglevel=0" # Set kernel log level to emergency only

    # Hardware RNG security
    "random.trust_cpu=off" # Don't trust CPU's hardware RNG - defense against backdoored CPUs
    "random.trust_bootloader=off" # Don't trust bootloader-provided randomness

    # IOMMU (Input-Output Memory Management Unit) for DMA attack prevention
    "intel_iommu=on" # Enable Intel IOMMU for DMA remapping
    "iommu=force" # Force enable IOMMU even on platforms that normally disable it
    "iommu.strict=1" # Use strict mode - TLB flush on each unmap (more secure, slight performance cost)
  ];

  environment.systemPackages = with pkgs; [
    tpm2-tools
    tpm2-abrmd
    efibootmgr
    efitools
    sbctl # secure boot key manager
  ];

  # Disable the editor in systemd-boot, the default bootloader for NixOS.
  # This prevents access to the root shell or otherwise weakening
  # security by tampering with boot parameters. If you use a different
  # boatloader, this does not provide anything. You may also want to
  # consider disabling similar functions in your choice of bootloader.
  boot.loader.systemd-boot.editor = false;

}
