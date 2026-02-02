{ config, pkgs, ... }:
{

  environment.systemPackages = [
    pkgs.nix-output-monitor # Better build progress display (nom)
  ];

  nix = {
    # Configure automatic package garbage collection
    gc = {
      automatic = true;
      dates = "monthly"; # First of each month
      persistent = true;
      options = "--delete-older-than 7d"; # Keep 7 days for rollback
    };

    # Ensure the cpu doesn't get blasted
    daemonCPUSchedPolicy = "idle";
    settings = {
      # Increase download buffer size to prevent warnings (1GB)
      download-buffer-size = 1073741824; # 1GB (1024 * 1024 * 1024)

      # Binary caches for faster builds (avoid compiling common packages)
      extra-substituters = [
        "https://install.determinate.systems"
        "https://nix-community.cachix.org"
      ];
      extra-trusted-public-keys = [
        "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      # Performance settings
      accept-flake-config = true; # Auto-accept flake.nix nixConfig settings
      warn-dirty = false; # Don't warn about dirty git trees
      use-xdg-base-directories = true;

      # Debugging - keep failed build directories for inspection
      keep-failed = true;

      # Build resource limits
      max-jobs = 8;
      cores = config.cpuCount - 1;
      keep-build-log = true;
      log-lines = 100;
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
