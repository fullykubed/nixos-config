{ config, pkgs, ... }:
{

  nix = {
    # Configure automatic package garbage collection
    gc = {
      automatic = true;
      dates = "*-*-* 00:00:00"; # Midnight daily
      persistent = true;
      options = "--delete-older-than 7d"; # Keep 7 days for rollback
    };

    # Ensure the cpu doesn't get blasted
    daemonCPUSchedPolicy = "idle";
    settings = {
      max-jobs = 16;
      # Increase download buffer size to prevent warnings (1GB)
      download-buffer-size = 1073741824; # 1GB (1024 * 1024 * 1024)
      # Determinate Systems cache
      extra-substituters = [ "https://install.determinate.systems" ];
      extra-trusted-public-keys = [ "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM=" ];
    };
  };

  # Add WakeSystem to the auto-generated nix-gc timer
  systemd.timers.nix-gc.timerConfig.WakeSystem = true;

  # Nix store optimization service
  systemd.services.nix-store-optimise = {
    description = "Nix Store Optimization";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/run/current-system/sw/bin/nix-store --optimise";
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
    };
  };

  # Timer for nix-store-optimise that runs after GC
  systemd.timers.nix-store-optimise = {
    description = "Nix Store Optimization Timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00:15:00"; # 15 minutes after midnight (after GC)
      Persistent = true;
      WakeSystem = true;
    };
  };
}
