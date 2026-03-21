{ pkgs, ... }:
{
  # Post-build hook: enqueue store paths for async upload to niks3 binary cache
  nix.settings.post-build-hook = "/etc/nix/enqueue-to-cache.sh";

  environment.etc."nix/enqueue-to-cache.sh" = {
    mode = "0555";
    text = ''
      #!/bin/sh
      set -eu
      set -f
      export IFS=' '

      PENDING_DIR="/var/lib/cache-upload-queue/pending"
      mkdir -p "$PENDING_DIR"

      for path in $OUT_PATHS; do
        hash=$(basename "$path" | cut -d- -f1)
        echo "$path" > "$PENDING_DIR/$hash"
      done
    '';
  };

  systemd = {
    services = {
      # Oneshot service that processes the cache upload queue
      # Retries every 5 minutes on failure, gives up after 6 hours (72 attempts)
      cache-upload = {
        description = "Process cache upload queue";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "simple";
          StateDirectory = "cache-upload-queue";
          Environment = [
            "NIKS3_AUTH_TOKEN_FILE=/run/niks3-auth-token"
            "NIKS3_SERVER_URL=http://nix-controller:5751"
          ];
          Restart = "on-failure";
          RestartSec = "5min";
          # Hardening
          ProtectSystem = "strict";
          ReadWritePaths = [ "/var/lib/cache-upload-queue" ];
          ReadOnlyPaths = [ "/nix/store" ];
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          PrivateDevices = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
            "@network-io"
          ];
          SystemCallArchitectures = "native";
        };
        # Disable start limit — path unit triggers frequently during active builds
        startLimitIntervalSec = 0;
        path = with pkgs; [
          niks3-cli
          nix
          coreutils
        ];
        script = builtins.readFile ../../modules/common/controller/upload-daemon.sh;
      };
    };

    paths.cache-upload = {
      description = "Watch cache upload queue for new items";
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        DirectoryNotEmpty = "/var/lib/cache-upload-queue/pending";
        MakeDirectory = true;
      };
    };

    timers.cache-upload = {
      description = "Retry cache uploads hourly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "1h";
      };
    };
  };
}
