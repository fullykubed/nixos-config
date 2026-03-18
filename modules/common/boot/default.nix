{
  lib,
  pkgs,
  ...
}:

{
  # Get extra entropy since we disabled hardware entropy sources
  # Read more about why at the following URLs:
  # https://github.com/smuellerDD/jitterentropy-rngd/issues/27
  # https://blogs.oracle.com/linux/post/rngd1
  services.jitterentropy-rngd.enable = true;

  boot = {
    # The linux kernl to use
    kernelPackages = pkgs.linuxPackages_6_18;

    # These are kernel modules needed at stage 1 of the boot process
    initrd.kernelModules = [
      "nvme" # NVME drives
      "xhci_pci" # USB 3.0
      "ahci" # SATA drives
      "usbhid" # USB HID devices
      "usb_storage" # USB storage devices
      "sd_mod" # SD card support
      "zfs" # ZFS support
    ];

    kernelModules = [
      # Monitoring device sensors
      "k10temp"
      "nct6775"
      "i2c-piix4"
      "lm92"
      "jitterentropy_rng"
    ];

    kernel.sysctl = {
      # See https://github.com/k3d-io/k3d/issues/116
      "fs.inotify.max_user_instances" = 1280;
      "fs.inotify.max_user_watches" = 655360;

      # Yama restricts ptrace, which allows processes to read and modify the
      # memory of other processes. This has obvious security implications.
      # Default value is 1, to only allow parent processes to ptrace child
      # processes. May be modified to restrict ptrace further.
      "kernel.yama.ptrace_scope" = "1";

      # Disables magic sysrq key.
      "kernel.sysrq" = "0";

      # Disable binfmt. Breaks Roseta, among other applications.
      # See https://en.wikipedia.org/wiki/Binfmt_misc for more info.
      "fs.binfmt_misc.status" = "0";

      # Disable io_uring. May be desired for Proxmox, but is responsible
      # for many vulnerabilities and is disabled on Android + ChromeOS.
      "kernel.io_uring_disabled" = "2";

      # Disable ip forwarding to reduce attack surface. May be needed for
      # VM networking.
      "net.ipv4.ip_forward" = "0";
      "net.ipv4.conf.all.forwarding" = "0";
      "net.ipv4.conf.default.forwarding" = "0";
      "net.ipv6.conf.all.forwarding" = "0";
      "net.ipv6.conf.default.forwarding" = "0";

      # Privacy/security split.
      # Enabling tcp-timestamps protects against wrapped sequence numbers
      # and improves performance, but can leak system time.
      # URL: (In favor of disabling): https://madaidans-insecurities.github.io/guides/linux-hardening.html#tcp-timestamps
      # URL: (In favor of enabling): https://access.redhat.com/sites/default/files/attachments/20150325_network_performance_tuning.pdf
      "net.ipv4.tcp_timestamps" = "1";

      "dev.tty.ldisc_autoload" = "0";
      "fs.protected_fifos" = "2";
      "fs.protected_hardlinks" = "1";
      "fs.protected_regular" = "2";
      "fs.protected_symlinks" = "1";
      "fs.suid_dumpable" = "0";
      "kernel.dmesg_restrict" = "1";
      "kernel.kexec_load_disabled" = "1";
      "kernel.kptr_restrict" = "2";
      "kernel.perf_event_paranoid" = "3";
      "kernel.printk" = "3 3 3 3";
      "kernel.unprivileged_bpf_disabled" = "1";
      "net.core.bpf_jit_harden" = "2";

      # Disable ICMP redirects to prevent some MITM attacks
      # See https://askubuntu.com/questions/118273/what-are-icmp-redirects-and-should-they-be-blocked
      "net.ipv4.conf.all.accept_redirects" = "0";
      "net.ipv4.conf.default.accept_redirects" = "0";
      "net.ipv4.conf.all.send_redirects" = "0";
      "net.ipv4.conf.default.send_redirects" = "0";
      "net.ipv6.conf.all.accept_redirects" = "0";
      "net.ipv6.conf.default.accept_redirects" = "0";

      # Use secure ICMP redirects by default. Helpful if ICMP redirects are
      # reenabled only.
      "net.ipv4.conf.all.secure_redirects" = "1";
      "net.ipv4.conf.default.secure_redirects" = "1";

      "net.ipv4.conf.all.accept_source_route" = "0";
      "net.ipv4.conf.all.rp_filter" = "1";
      "net.ipv4.conf.default.accept_source_route" = "0";
      "net.ipv4.conf.default.rp_filter" = "1";
      "net.ipv4.icmp_echo_ignore_all" = "1";
      "net.ipv6.icmp_echo_ignore_all" = "1";
      "net.ipv4.tcp_dsack" = "0";
      "net.ipv4.tcp_fack" = "0";
      "net.ipv4.tcp_rfc1337" = "1";
      "net.ipv4.tcp_sack" = "0";
      "net.ipv4.tcp_syncookies" = "1";
      "net.ipv6.conf.all.accept_ra" = "0";
      "net.ipv6.conf.all.accept_source_route" = "0";
      "net.ipv6.conf.default.accept_source_route" = "0";
      "net.ipv6.default.accept_ra" = "0";
      "kernel.core_pattern" = "|/bin/false";
      "vm.mmap_rnd_bits" = "32";
      "vm.mmap_rnd_compat_bits" = "16";
      "vm.unprivileged_userfaultfd" = "0";
      "net.ipv4.icmp_ignore_bogus_error_responses" = "1";

      # Enable ASLR
      # Turn on protection and randomize stack, vdso page and mmap + randomize brk base address
      "kernel.randomize_va_space" = "2";

      # Restrict perf subsystem usage (activity) further
      "kernel.perf_cpu_time_max_percent" = "1";
      "kernel.perf_event_max_sample_rate" = "1";

      # Do not allow mmap in lower addresses
      "vm.mmap_min_addr" = "65536";

      # Log packets with impossible addresses to kernel log
      # No active security benefit, just makes it easier to spot a DDOS/DOS by giving
      # extra logs
      "net.ipv4.conf.default.log_martians" = "1";
      "net.ipv4.conf.all.log_martians" = "1";

      # Disable sending and receiving of shared media redirects
      # This setting overwrites net.ipv4.conf.all.secure_redirects
      # Refer to RFC1620
      "net.ipv4.conf.default.shared_media" = "0";
      "net.ipv4.conf.all.shared_media" = "0";

      # Always use the best local address for announcing local IP via ARP
      # Seems to be most restrictive option
      "net.ipv4.conf.default.arp_announce" = "2";
      "net.ipv4.conf.all.arp_announce" = "2";

      # Reply only if the target IP address is local address configured on the incoming interface
      "net.ipv4.conf.default.arp_ignore" = "1";
      "net.ipv4.conf.all.arp_ignore" = "1";

      # Drop Gratuitous ARP frames to prevent ARP poisoning
      # This can cause issues when ARP proxies are used in the network
      "net.ipv4.conf.default.drop_gratuitous_arp" = "1";
      "net.ipv4.conf.all.drop_gratuitous_arp" = "1";

      # Ignore all ICMP echo and timestamp requests sent to broadcast/multicast
      "net.ipv4.icmp_echo_ignore_broadcasts" = "1";

      # Number of Router Solicitations to send until assuming no routers are present
      "net.ipv6.conf.default.router_solicitations" = "0";
      "net.ipv6.conf.all.router_solicitations" = "0";

      # Do not accept Router Preference from RA
      "net.ipv6.conf.default.accept_ra_rtr_pref" = "0";
      "net.ipv6.conf.all.accept_ra_rtr_pref" = "0";

      # Learn prefix information in router advertisement
      "net.ipv6.conf.default.accept_ra_pinfo" = "0";
      "net.ipv6.conf.all.accept_ra_pinfo" = "0";

      # Setting controls whether the system will accept Hop Limit settings from a router advertisement
      "net.ipv6.conf.default.accept_ra_defrtr" = "0";
      "net.ipv6.conf.all.accept_ra_defrtr" = "0";

      # Router advertisements can cause the system to assign a global unicast address to an interface
      "net.ipv6.conf.default.autoconf" = "0";
      "net.ipv6.conf.all.autoconf" = "0";

      # Number of neighbor solicitations to send out per address
      "net.ipv6.conf.default.dad_transmits" = "0";
      "net.ipv6.conf.all.dad_transmits" = "0";

      # Number of global unicast IPv6 addresses can be assigned to each interface
      "net.ipv6.conf.default.max_addresses" = "1";
      "net.ipv6.conf.all.max_addresses" = "1";

      # Ignore all ICMPv6 echo requests
      "net.ipv6.icmp.echo_ignore_all" = "1";
      "net.ipv6.icmp.echo_ignore_anycast" = "1";
      "net.ipv6.icmp.echo_ignore_multicast" = "1";
    };

    loader = {
      systemd-boot = {
        enable = lib.mkForce false;
        # Disable the editor in systemd-boot, the default bootloader for NixOS.
        # This prevents access to the root shell or otherwise weakening
        # security by tampering with boot parameters. If you use a different
        # boatloader, this does not provide anything. You may also want to
        # consider disabling similar functions in your choice of bootloader.
        editor = false;
      };
      efi = {
        efiSysMountPoint = "/boot1";
        canTouchEfiVariables = true;
      };
    };

    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };

    kernelParams = [
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
      "iommu.passthrough=0" # Forces DMA to go through IOMMU to mitigate some DMA attacks

      # Additional security mitigations
      "efi=disable_early_pci_dma" # May prevent some systems from booting
      "mitigations=auto,nosmt" # Apply relevant CPU exploit mitigations, and disable symmetric multithreading. May harm performance.
      "pti=on" # Mitigates Meltdown, some KASLR bypasses. Hurts performance.
      "extra_latent_entropy" # Gather more entropy on boot. Only works with the linux_hardened patchset, but does nothing if using another kernel. Slows down boot time by a bit.
    ];
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

  # Shared Secure Boot PKI — private keys decrypted by agenix, public certs copied from repo
  age.secrets = {
    secureboot-pk-key = {
      rekeyFile = ../../../secrets/secureboot-pk-key.age;
      path = "/etc/secureboot/keys/PK/PK.key";
      mode = "0400";
      owner = "root";
    };
    secureboot-kek-key = {
      rekeyFile = ../../../secrets/secureboot-kek-key.age;
      path = "/etc/secureboot/keys/KEK/KEK.key";
      mode = "0400";
      owner = "root";
    };
    secureboot-db-key = {
      rekeyFile = ../../../secrets/secureboot-db-key.age;
      path = "/etc/secureboot/keys/db/db.key";
      mode = "0400";
      owner = "root";
    };
  };

  # Copies the EFI partition to a backup partition. This allows us to boot even if the first
  # drive becomes corrupted.
  system.activationScripts = {
    boot-sync.text = ''
      for dir in /boot[0-9]*; do
        [ "$dir" = "/boot1" ] && continue
        ${pkgs.util-linux}/bin/mountpoint -q "$dir" && \
          ${pkgs.rsync}/bin/rsync -avq --delete /boot1/ "$dir/"
      done
    '';
  };

  # Auto-enroll Secure Boot keys when UEFI firmware is in Setup Mode.
  # After a fresh install, put the firmware in Setup Mode via BIOS and reboot —
  # this service will enroll the keys automatically.
  systemd.services.secureboot-enroll = {
    description = "Enroll Secure Boot keys when firmware is in Setup Mode";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [
      sbctl
      jaq
    ];
    script = ''
      setup_mode=$(sbctl status --json | jaq -r '.setup_mode')
      if [[ "$setup_mode" != "true" ]]; then
        echo "Setup Mode not active, skipping key enrollment"
        exit 0
      fi

      echo "Setup Mode detected — enrolling Secure Boot keys..."
      sbctl enroll-keys
      echo "Keys enrolled. Secure Boot will be active on next reboot."
    '';
  };

  environment = {
    # Use graphene-hardened memory allocator for improved security
    # Options: "libc" (default), "graphene-hardened", "graphene-hardened-light", "scudo", "jemalloc", "mimalloc"
    memoryAllocator.provider = "graphene-hardened";

    # Secure Boot public certificates and GUID
    etc = {
      "secureboot/GUID".source = ../../../secrets/secureboot-GUID;
      "secureboot/keys/PK/PK.pem".source = ../../../secrets/secureboot-pk.pem;
      "secureboot/keys/KEK/KEK.pem".source = ../../../secrets/secureboot-kek.pem;
      "secureboot/keys/db/db.pem".source = ../../../secrets/secureboot-db.pem;
    };

    systemPackages = with pkgs; [
      tpm2-tools
      tpm2-abrmd
      efibootmgr
      efitools
      sbctl # secure boot key manager
    ];
  };
}
