# Security hardening for the controller VM.
#
# The controller is internet-facing (Headscale, Caddy on ports 80/443) so it
# keeps full kernel security mitigations enabled.
_: {
  boot = {
    # ── Kernel sysctl hardening ──────────────────────────────────────────
    kernel.sysctl = {
      # Memory
      "kernel.randomize_va_space" = "2";
      "vm.mmap_min_addr" = "65536";
      "vm.mmap_rnd_bits" = "32";
      "vm.mmap_rnd_compat_bits" = "16";
      "fs.suid_dumpable" = "0";
      "kernel.core_pattern" = "|/bin/false";
      "vm.unprivileged_userfaultfd" = "0";

      # Kernel self-protection
      "kernel.dmesg_restrict" = "1";
      "kernel.kptr_restrict" = "2";
      "kernel.yama.ptrace_scope" = "1";
      "kernel.sysrq" = "0";
      "kernel.unprivileged_bpf_disabled" = "1";
      "net.core.bpf_jit_harden" = "2";
      "kernel.perf_event_paranoid" = "3";
      "kernel.perf_cpu_time_max_percent" = "1";
      "kernel.perf_event_max_sample_rate" = "1";
      "kernel.kexec_load_disabled" = "1";
      "kernel.io_uring_disabled" = "2";
      "kernel.printk" = "3 3 3 3";
      "dev.tty.ldisc_autoload" = "0";
      "fs.binfmt_misc.status" = "0";

      # Network: syncookies, rfc1337, disable redirects/source_route, rp_filter
      "net.ipv4.tcp_syncookies" = "1";
      "net.ipv4.tcp_rfc1337" = "1";
      "net.ipv4.tcp_timestamps" = "1";
      "net.ipv4.tcp_sack" = "0";
      "net.ipv4.tcp_dsack" = "0";
      "net.ipv4.tcp_fack" = "0";
      "net.ipv4.conf.all.accept_redirects" = "0";
      "net.ipv4.conf.default.accept_redirects" = "0";
      "net.ipv4.conf.all.send_redirects" = "0";
      "net.ipv4.conf.default.send_redirects" = "0";
      "net.ipv4.conf.all.secure_redirects" = "1";
      "net.ipv4.conf.default.secure_redirects" = "1";
      "net.ipv4.conf.all.accept_source_route" = "0";
      "net.ipv4.conf.default.accept_source_route" = "0";
      "net.ipv4.conf.all.rp_filter" = "1";
      "net.ipv4.conf.default.rp_filter" = "1";
      "net.ipv4.icmp_echo_ignore_all" = "1";
      "net.ipv4.icmp_echo_ignore_broadcasts" = "1";
      "net.ipv4.icmp_ignore_bogus_error_responses" = "1";
      "net.ipv4.conf.default.log_martians" = "1";
      "net.ipv4.conf.all.log_martians" = "1";
      "net.ipv4.conf.default.shared_media" = "0";
      "net.ipv4.conf.all.shared_media" = "0";
      "net.ipv4.ip_forward" = "0";
      "net.ipv4.conf.all.forwarding" = "0";
      "net.ipv4.conf.default.forwarding" = "0";

      # ARP hardening
      "net.ipv4.conf.default.arp_announce" = "2";
      "net.ipv4.conf.all.arp_announce" = "2";
      "net.ipv4.conf.default.arp_ignore" = "1";
      "net.ipv4.conf.all.arp_ignore" = "1";
      "net.ipv4.conf.default.drop_gratuitous_arp" = "1";
      "net.ipv4.conf.all.drop_gratuitous_arp" = "1";

      # IPv6: disable RA, autoconf, router solicitations (Hetzner uses IPv4 DHCP)
      "net.ipv6.conf.all.accept_redirects" = "0";
      "net.ipv6.conf.default.accept_redirects" = "0";
      "net.ipv6.conf.all.accept_source_route" = "0";
      "net.ipv6.conf.default.accept_source_route" = "0";
      "net.ipv6.conf.all.accept_ra" = "0";
      "net.ipv6.default.accept_ra" = "0";
      "net.ipv6.conf.all.forwarding" = "0";
      "net.ipv6.conf.default.forwarding" = "0";
      "net.ipv6.conf.default.router_solicitations" = "0";
      "net.ipv6.conf.all.router_solicitations" = "0";
      "net.ipv6.conf.default.accept_ra_rtr_pref" = "0";
      "net.ipv6.conf.all.accept_ra_rtr_pref" = "0";
      "net.ipv6.conf.default.accept_ra_pinfo" = "0";
      "net.ipv6.conf.all.accept_ra_pinfo" = "0";
      "net.ipv6.conf.default.accept_ra_defrtr" = "0";
      "net.ipv6.conf.all.accept_ra_defrtr" = "0";
      "net.ipv6.conf.default.autoconf" = "0";
      "net.ipv6.conf.all.autoconf" = "0";
      "net.ipv6.conf.default.dad_transmits" = "0";
      "net.ipv6.conf.all.dad_transmits" = "0";
      "net.ipv6.conf.default.max_addresses" = "1";
      "net.ipv6.conf.all.max_addresses" = "1";
      "net.ipv6.icmp_echo_ignore_all" = "1";
      "net.ipv6.icmp.echo_ignore_all" = "1";
      "net.ipv6.icmp.echo_ignore_anycast" = "1";
      "net.ipv6.icmp.echo_ignore_multicast" = "1";

      # Filesystem: protected hardlinks/symlinks/fifos/regular
      "fs.protected_hardlinks" = "1";
      "fs.protected_symlinks" = "1";
      "fs.protected_fifos" = "2";
      "fs.protected_regular" = "2";
    };

    # ── Boot kernel params ────────────────────────────────────────────────
    # Omitted vs local machines: intel_iommu, iommu.*, efi=disable_early_pci_dma
    # (hypervisor-managed), nosmt (cloud VMs need all vCPUs).
    kernelParams = [
      "slab_nomerge"
      "init_on_alloc=1"
      "init_on_free=1"
      "page_alloc.shuffle=1"
      "randomize_kstack_offset=on"
      "vsyscall=none"
      "debugfs=off"
      "oops=panic"
      "random.trust_cpu=off"
      "random.trust_bootloader=off"
      "mitigations=auto"
      "pti=on"
    ];

    # ── Blacklisted kernel modules ───────────────────────────────────────
    # Unused protocols and filesystems that increase attack surface
    blacklistedKernelModules = [
      # Unused network protocols
      "dccp"
      "sctp"
      "rds"
      "tipc"
      "n-hdlc"
      "ax25"
      "netrom"
      "x25"
      "rose"
      "decnet"
      "econet"
      "af_802154"
      "ipx"
      "appletalk"
      "can"
      "atm"
      # Unused filesystems
      "cramfs"
      "freevxfs"
      "jffs2"
      "hfs"
      "hfsplus"
      "udf"
      # Unused hardware buses (not present in cloud VMs)
      "firewire-core"
      "thunderbolt"
    ];
  };

  # Disable kexec and hibernation
  security.protectKernelImage = true;

  # Don't store coredumps
  systemd.coredump.extraConfig = "Storage=none";

  # Compensate for distrusted CPU/bootloader RNG
  services.jitterentropy-rngd.enable = true;
}
