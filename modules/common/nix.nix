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
    settings.max-jobs = 16;
  };
}
