{ pkgs, ... }:
let
  debounce-reindex = pkgs.writeShellScript "plocate-debounce-reindex" ''
    sleep 60
    systemctl start update-locatedb.service
  '';
in
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

  # Reactive reindex when /nix/store changes (60s debounce)
  systemd.paths.plocate-nix-store-watch = {
    description = "Watch /nix/store for changes to trigger plocate reindex";
    wantedBy = [ "paths.target" ];
    pathConfig = {
      PathModified = "/nix/store";
    };
  };

  systemd.services.plocate-nix-store-watch = {
    description = "Debounced plocate reindex after Nix store changes";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = debounce-reindex;
    };
  };
}
