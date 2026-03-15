_: {
  # Nix daemon configuration for remote builds
  # Defaults are tuned for regular builders (4 core per job).
  # Big-parallel builders override via /etc/nix/builder-override.conf at boot.
  nix = {
    settings = {
      trusted-users = [
        "root"
        "remotebuild"
      ];
      max-jobs = 4;
      cores = 4; # 4 core per job (regular builder default)
      eval-cores = 3; # Parallelize Nix evaluation (import/IFD)
      keep-going = true;
      lazy-locks = true;
      lazy-trees = true;
      max-silent-time = 1800;
      fallback = true;
      timeout = 21600;
      allow-import-from-derivation = false;
      experimental-features = [
        "nix-command"
        "flakes"
        "cgroups"
        "parallel-eval"
      ];
      use-cgroups = true;
      auto-optimise-store = true;

      # Substituter timeouts - fail fast if a cache is slow or unreachable
      connect-timeout = 5;
      stalled-download-timeout = 15;
    };
    extraOptions = ''
      !include /etc/nix/builder-override.conf
    '';
    gc = {
      automatic = false;
    };
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";
  };

  # Ensure the override conf exists (empty by default; cloud-init writes it for big builders)
  systemd.tmpfiles.rules = [
    "f /etc/nix/builder-override.conf 0644 root root - "
  ];

  # Memory limits scale with server RAM
  # No systemd sandboxing on nix-daemon — it needs full privilege control for
  # build sandboxing (namespaces, setuid to nixbld users, mounting).
  # Most Protect*/Restrict*/Lock* directives implicitly set NoNewPrivileges=yes
  # via seccomp filters, which breaks nix's namespace-based sandbox.
  systemd.services.nix-daemon.serviceConfig = {
    MemoryMax = "90%";
    MemoryHigh = "85%";
  };
}
