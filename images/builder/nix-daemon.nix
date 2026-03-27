# Nix daemon configuration for remote builds.
# Shared settings come from ../common/nix-settings.nix (imported in image.nix).
# Defaults here are tuned for regular builders (all cores per job).
# Big-parallel builders override via /etc/nix/builder-override.conf at boot.
_: {
  nix = {
    settings = {
      trusted-users = [
        "root"
        "remotebuild"
      ];
      max-jobs = 10;
      cores = 0;
      eval-cores = 3;
      fsync-metadata = false;
    };
    extraOptions = ''
      !include /etc/nix/builder-override.conf
    '';
    daemonIOSchedClass = "idle";
  };

  # Ensure the override conf exists (empty by default; cloud-init writes it for big builders)
  systemd.tmpfiles.rules = [
    "f /etc/nix/builder-override.conf 0644 root root - "
  ];

  # Memory limits scale with server RAM
  # No systemd sandboxing on nix-daemon — it needs full privilege control for
  # build sandboxing (namespaces, setuid to nixbld users, mounting).
  systemd.services.nix-daemon = {
    # Start after secrets-ready so big-builder override conf is written before first read
    after = [ "secrets-ready.target" ];
    requires = [ "secrets-ready.target" ];
    serviceConfig = {
      MemoryMax = "90%";
      MemoryHigh = "85%";
    };
  };
}
