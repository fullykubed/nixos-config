# Shared Nix daemon settings applied to all NixOS systems and disk images.
# Consumer-specific overrides (GC policy, job limits, trusted-users, etc.)
# are set in modules/common/nix/ (local) or images/*/nix-daemon.nix (cloud).
{ lib, ... }:
{
  nix = {
    daemonCPUSchedPolicy = "idle";
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "ca-derivations"
        "cgroups"
        "parallel-eval"
      ];
      use-cgroups = true;
      keep-going = true;
      lazy-locks = true;
      lazy-trees = true;
      max-silent-time = 1800;
      fallback = true;
      timeout = 21600;
      allow-import-from-derivation = false;
      keep-env-derivations = true;
      auto-optimise-store = true;

      download-buffer-size = 1073741824; # 1GB
      max-substitution-jobs = 32;

      # Substituter connection tuning
      http-connections = 1000;
      download-attempts = 1;
      connect-timeout = 5;
      stalled-download-timeout = 15;
      narinfo-cache-negative-ttl = 60; # Re-check cache misses after 60s (default 1h)

      # Only niks3 is an active substituter — it's the only cache with our
      # custom-stdenv derivations. cache.nixos.org, cachix, and determinate.systems
      # would 404 on every lookup, adding ~25k wasted narinfo requests per rebuild.
      substituters = lib.mkForce [
        "https://nixos-cache.panfactumcf.com?priority=1" # niks3 binary cache
      ];
      trusted-substituters = [
        "https://cache.flakehub.com"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cache-1:L8UZuJh5BeVhxU06bO4iT0OkWSvKO7/nFV1XuOwt9ak="
        "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
        "cache.flakehub.com-4:Asi8qIv291s0aYLyH6IOnr5Kf6+OF14WVjkE6t3xMio="
        "cache.flakehub.com-5:zB96CRlL7tiPtzA9/WKyPkp3A2vqxqgdgyTVNGShPDU="
        "cache.flakehub.com-6:W4EGFwAGgBj3he7c5fNh9NkOXw0PUVaxygCVKeuvaqU="
        "cache.flakehub.com-7:mvxJ2DZVHn/kRxlIaxYNMuDG1OvMckZu32um1TadOR8="
        "cache.flakehub.com-8:moO+OVS0mnTjBTcOUh2kYLQEd59ExzyoW1QgQ8XAARQ="
        "cache.flakehub.com-9:wChaSeTI6TeCuV/Sg2513ZIM9i0qJaYsF+lZCXg0J6o="
        "cache.flakehub.com-10:2GqeNlIp6AKp4EF2MVbE1kBOp9iBSyo0UPR9KoR0o1Y="
      ];
    };
  };
}
