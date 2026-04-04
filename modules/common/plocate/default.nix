{ pkgs, ... }:
{
  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "hourly";
    prunePaths = [
      "/tmp"
      "/var/tmp"
      "/var/cache"
      "/var/lock"
      "/var/run"
      "/var/spool"
      "/nix/var/log/nix"
    ];
  };

  # Reactive reindex when /nix/store changes (60s debounce via timer)
  systemd = {
    paths.plocate-nix-store-watch = {
      description = "Watch /nix/store for changes to trigger plocate reindex";
      wantedBy = [ "paths.target" ];
      pathConfig = {
        PathModified = "/nix/store";
        Unit = "plocate-nix-store-debounce.timer";
      };
    };

    # Each path trigger resets the 60s countdown
    timers.plocate-nix-store-debounce = {
      description = "Debounce timer for plocate Nix store reindex";
      timerConfig = {
        OnActiveSec = "60s";
        Unit = "plocate-nix-store-reindex.service";
      };
    };

    services.plocate-nix-store-reindex = {
      description = "Reindex plocate database after Nix store changes";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl start update-locatedb.service";
      };
    };
  };
}
