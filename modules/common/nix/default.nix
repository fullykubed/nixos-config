{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkMerge [
  {
    environment.systemPackages = [
      pkgs.nix-output-monitor # Better build progress display (nom)
      pkgs.nix-tree # Interactively browse dependency graphs of Nix derivations
    ];

    nix = {
      # Configure automatic package garbage collection
      gc = {
        automatic = true;
        dates = "monthly"; # First of each month
        persistent = true;
        options = "--delete-older-than 7d"; # Keep 7 days for rollback
      };

      settings = {
        # Performance settings
        accept-flake-config = true; # Auto-accept flake.nix nixConfig settings
        trusted-users = [
          "root"
          config.username
        ];
        warn-dirty = false; # Don't warn about dirty git trees
        use-xdg-base-directories = true;

        # Debugging - keep failed build directories for inspection
        keep-failed = true;

        # Build resource limits
        max-jobs = (config.cpuCount + 3) / 4;
        cores = config.cpuCount - 1;
        eval-cores = config.cpuCount - 1; # Parallelize Nix evaluation (import/IFD)
        keep-build-log = true;
        log-lines = 100;

        # Retain build outputs and derivations so nix-shell/nix develop can
        # reuse them without re-downloading or rebuilding
        keep-outputs = true;
        keep-derivations = true;
      };
    };

    systemd = {
      # Add WakeSystem to the auto-generated nix-gc timer
      timers.nix-gc.timerConfig.WakeSystem = true;

      # Nix daemon resource limits
      services.nix-daemon.serviceConfig = {
        MemoryMax = "32G";
        MemoryHigh = "30G";
        AllowedCPUs = "0-${toString (config.cpuCount - 2)}"; # Leave 1 core free
        Nice = 19; # Lowest CPU priority
        OOMScoreAdjust = 1000; # Kill nix builds first when OOM occurs
      };

      # Nix store optimization service
      services.nix-store-optimise = {
        description = "Nix Store Optimization";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "/run/current-system/sw/bin/nix-store --optimise";
          CPUSchedulingPolicy = "idle";
          IOSchedulingClass = "idle";
        };
      };

      # Timer for nix-store-optimise that runs after GC
      timers.nix-store-optimise = {
        description = "Nix Store Optimization Timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-01 00:15:00"; # 15 minutes after GC on first of month
          Persistent = true;
          WakeSystem = true;
        };
      };
    };
  }

  # ── Remote-builder Nix daemon tuning ────────────────────────────────────────
  # Overrides the defaults above for build-dedicated machines.
  # trusted-users adds "remotebuild" on top of the base list (root + username).
  # max-jobs and cores are tuned for sustained parallel compilation rather than
  # interactive use. fsync-metadata=false trades durability for I/O throughput
  # (acceptable because the store is rebuilt from source on each boot).
  # The nix-daemon systemd unit gets generous memory headroom since the whole
  # machine is dedicated to builds.
  (lib.mkIf (config.deviceType == "remote-builder") {
    nix.settings = {
      trusted-users = [ "remotebuild" ];
      max-jobs = lib.mkForce 10;
      cores = lib.mkForce 0; # 0 = auto (use all cores per job)
      fsync-metadata = false;
    };

    nix.daemonIOSchedClass = "idle";

    systemd.services.nix-daemon.serviceConfig = {
      MemoryMax = lib.mkForce "90%";
      MemoryHigh = lib.mkForce "85%";
      LimitNOFILE = 1048576;
    };
  })
]
