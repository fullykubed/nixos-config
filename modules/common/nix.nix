{ config, pkgs, ... }:
{

  nix = {
    # Configure automatic package garbage collection
    gc = {
      automatic = true;
      dates = "05:00";
      persistent = true;
      options = "-d"; # ensures old profiles are cleaned
    };

    # Ensure the cpu doesn't get blasted
    daemonCPUSchedPolicy = "idle";
    settings = {
      max-jobs = 16;
      # Increase download buffer size to prevent warnings (1GB)
      download-buffer-size = 1073741824; # 1GB (1024 * 1024 * 1024)
    };
  };
}
