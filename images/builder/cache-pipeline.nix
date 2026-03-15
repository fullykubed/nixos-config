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
      # SSH tunnel to cache server for pushing build artifacts
      # Forwards local:9751 → cache:5751 (niks3) via SSH port 3099
      cache-tunnel = {
        description = "SSH tunnel to niks3 cache server";
        after = [
          "cloud-init.service"
          "network-online.target"
        ];
        wants = [
          "cloud-init.service"
          "network-online.target"
        ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "10s";
          ExecStopPost = "-${pkgs.coreutils}/bin/rm -f /run/niks3-server-url";
          # Hardening
          ProtectSystem = "strict";
          ReadWritePaths = [ "/run" ];
          ProtectHome = "tmpfs";
          BindReadOnlyPaths = [
            "/root/.ssh/cache-key"
            "/etc/ssh/cache-host-key.pub"
          ];
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
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
        path = with pkgs; [
          hcloud
          jq
          openssh
          coreutils
          bash
        ];
        script = ''
          # Wait for cloud-init to write keys
          while [ ! -f /root/.ssh/cache-key ] || [ ! -f /etc/ssh/cache-host-key.pub ]; do
            echo "Waiting for cloud-init to write cache keys..."
            sleep 5
          done

          export HCLOUD_TOKEN
          HCLOUD_TOKEN=$(cat /run/hcloud-token)

          # Find cache server IP
          CACHE_IP=""
          while [ -z "$CACHE_IP" ]; do
            CACHE_IP=$(hcloud server list -l cache=true -o json | jq -r '.[0].public_net.ipv4.ip // empty')
            if [ -z "$CACHE_IP" ]; then
              echo "WARNING: No cache server found (label cache=true). Retrying in 60s..."
              sleep 60
            fi
          done
          echo "Found cache server at $CACHE_IP"

          KNOWN_HOSTS=$(mktemp)
          trap 'rm -f "$KNOWN_HOSTS"' EXIT
          echo "[$CACHE_IP]:3099 $(cat /etc/ssh/cache-host-key.pub)" > "$KNOWN_HOSTS"

          # Start SSH tunnel in background
          ssh -N -L 9751:127.0.0.1:5751 \
            -i /root/.ssh/cache-key \
            -p 3099 \
            -o StrictHostKeyChecking=yes \
            -o "UserKnownHostsFile=$KNOWN_HOSTS" \
            -o ServerAliveInterval=30 \
            -o ServerAliveCountMax=3 \
            -o ExitOnForwardFailure=yes \
            -o BatchMode=yes \
            root@"$CACHE_IP" &
          SSH_PID=$!

          # Only signal readiness once the tunnel port is listening
          for i in $(seq 1 30); do
            if bash -c "echo >/dev/tcp/127.0.0.1/9751" 2>/dev/null; then
              echo "Tunnel established to $CACHE_IP"
              echo "http://127.0.0.1:9751" > /run/niks3-server-url
              chmod 0444 /run/niks3-server-url
              wait $SSH_PID
              exit $?
            fi
            sleep 1
          done

          echo "ERROR: Tunnel port 9751 did not become available"
          kill $SSH_PID 2>/dev/null || true
          exit 1
        '';
      };

      # Oneshot service that processes the cache upload queue
      # Retries every 5 minutes on failure, gives up after 6 hours (72 attempts)
      cache-upload = {
        description = "Process cache upload queue";
        after = [
          "network-online.target"
          "cache-tunnel.service"
        ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          StateDirectory = "cache-upload-queue";
          Environment = "NIKS3_AUTH_TOKEN_FILE=/run/niks3-auth-token";
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
        script = builtins.readFile ../../modules/common/binary-cache/upload-daemon.sh;
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
