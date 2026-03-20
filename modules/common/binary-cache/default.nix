{
  config,
  lib,
  pkgs,
  ...
}:
let
  maxCacheServers = 1;

  # Cache host public key for SSH.
  cacheHostPublicKey = builtins.readFile ../../../secrets/cache-host-key.pub;

  # Known hosts file for SSH host key verification
  cacheKnownHosts = pkgs.writeText "cache-known-hosts" (
    let
      hostKey = lib.removeSuffix "\n" cacheHostPublicKey;
      entries = lib.genList (n: "cache-${toString (n + 1)} ${hostKey}") maxCacheServers;
    in
    lib.concatStringsSep "\n" entries + "\n"
  );

  # CLI tool for managing cache servers (defined first so proxy can use it)
  cacheCli = pkgs.writeShellApplication {
    name = "cache";
    runtimeInputs = [
      pkgs.hcloud
      pkgs.jaq
      pkgs.bc
      pkgs.ncurses
      pkgs.nix
    ];
    text = builtins.readFile ./cache-cli.sh;
  };

  # Proxy command for SSH that handles cache server connections
  cacheProxyScript = pkgs.writeShellApplication {
    name = "hetzner-cache-proxy";
    runtimeInputs = [
      pkgs.hcloud
      pkgs.jaq
      pkgs.netcat-gnu
      pkgs.socat
      pkgs.openssh
      cacheCli
    ];
    text = builtins.readFile ./proxy-command.sh;
  };

  # Queue directory for async cache uploads
  queueDir = "/var/lib/cache-upload-queue";

  # Post-build-hook script: enqueues store paths for async upload
  enqueueScript = pkgs.writeShellScript "enqueue-to-cache" ''
    set -eu
    set -f
    export IFS=' '

    PENDING_DIR="${queueDir}/pending"

    # Ensure queue directory exists (first run after boot)
    ${pkgs.coreutils}/bin/mkdir -p "$PENDING_DIR"

    for path in $OUT_PATHS; do
      hash=$(${pkgs.coreutils}/bin/basename "$path" | ${pkgs.coreutils}/bin/cut -d- -f1)
      echo "$path" > "$PENDING_DIR/$hash"
    done
  '';

  # Upload oneshot script
  uploadScript = pkgs.writeShellApplication {
    name = "cache-upload";
    runtimeInputs = [
      pkgs.niks3-cli
      pkgs.nix
      pkgs.coreutils
    ];
    text = builtins.readFile ./upload-daemon.sh;
  };

  tokenPath = config.age.secrets.hetzner-api-token.path;

  # Wrappers that auto-load the Hetzner API token for interactive root use
  hcloudWrapped = pkgs.writeShellScriptBin "hcloud" ''
    export HCLOUD_TOKEN
    HCLOUD_TOKEN=$(cat ${tokenPath})
    exec ${pkgs.hcloud}/bin/hcloud "$@"
  '';
  hcloudUploadImageWrapped = pkgs.writeShellScriptBin "hcloud-upload-image" ''
    export HCLOUD_TOKEN
    HCLOUD_TOKEN=$(cat ${tokenPath})
    exec ${pkgs.hcloud-upload-image}/bin/hcloud-upload-image "$@"
  '';
in
{
  environment = {
    systemPackages = [
      cacheCli
      pkgs.hcloud # Hetzner Cloud CLI
      pkgs.bc # Calculator for cost estimation
      pkgs.socat # For SSH proxy command
      pkgs.hcloud-upload-image # Upload custom images to Hetzner Cloud
      pkgs.niks3-cli # For pushing build results to cache
    ];

    # Place the public keys in /etc/ssh
    etc = {
      "cache-ssh-key.pub" = {
        source = ../../../secrets/cache-ssh-key.pub;
        target = "ssh/cache-key.pub";
        mode = "0444";
      };

      "cache-host-key.pub" = {
        source = ../../../secrets/cache-host-key.pub;
        target = "ssh/cache-host-key.pub";
        mode = "0444";
      };

      "cache-signing-key.pub" = {
        source = ../../../secrets/cache-signing-key.pub;
        target = "ssh/cache-signing-key.pub";
        mode = "0444";
      };
    };
  };

  # Token-injecting wrappers for interactive root use
  home-manager.users.root.home.packages = [
    hcloudWrapped
    hcloudUploadImageWrapped
  ];

  # Secrets for Hetzner API and cache management
  # Note: hetzner-api-token is already declared in remote-builders module
  # We only declare cache-specific secrets here
  age.secrets = {
    cache-ssh-key = {
      rekeyFile = ../../../secrets/cache-ssh-key.age;
      path = "/root/.ssh/cache-key";
      mode = "0400";
      owner = "root";
    };
    cache-host-key = {
      rekeyFile = ../../../secrets/cache-host-key.age;
      path = "/run/agenix/cache-host-key";
      mode = "0400";
      owner = "root";
    };
    cache-signing-key = {
      rekeyFile = ../../../secrets/cache-signing-key.age;
      path = "/run/agenix/cache-signing-key";
      mode = "0400";
      owner = "root";
    };
    niks3-api-token = {
      rekeyFile = ../../../secrets/niks3-api-token.age;
      path = "/run/agenix/niks3-api-token";
      mode = "0400";
      owner = "root";
    };
    r2-access-key = {
      rekeyFile = ../../../secrets/r2-access-key.age;
      path = "/run/agenix/r2-access-key";
      mode = "0400";
      owner = "root";
    };
    r2-secret-key = {
      rekeyFile = ../../../secrets/r2-secret-key.age;
      path = "/run/agenix/r2-secret-key";
      mode = "0400";
      owner = "root";
    };
    cloudflare-dns-token = {
      rekeyFile = ../../../secrets/cloudflare-dns-token.age;
      path = "/run/agenix/cloudflare-dns-token";
      mode = "0400";
      owner = "root";
    };
  };

  systemd = {
    services = {
      # Systemd service that polls hcloud for cache server status and writes to a
      # world-readable file so unprivileged processes (waybar) can read it.
      cache-status = {
        description = "Poll Hetzner Cloud for cache server status";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          RuntimeDirectory = "cache-status";
          RuntimeDirectoryPreserve = "yes";
          EnvironmentFile = ""; # clear any inherited env
        };
        path = [
          pkgs.hcloud
          pkgs.jaq
        ];
        script = ''
          export HCLOUD_TOKEN
          HCLOUD_TOKEN=$(cat ${config.age.secrets.hetzner-api-token.path})
          hcloud server list -o json -l controller=true > /run/cache-status/status.json.tmp
          chmod 0644 /run/cache-status/status.json.tmp
          mv /run/cache-status/status.json.tmp /run/cache-status/status.json
        '';
      };

      # Discover the controller's Tailscale IP and write /run/niks3-server-url.
      # No SSH tunnel needed — niks3 now listens on 0.0.0.0:5751 and is reachable
      # directly from any Tailscale peer.
      cache-tunnel = {
        description = "Discover nix-controller Tailscale IP and write niks3 server URL";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "10s";
          ExecStopPost = "-${pkgs.coreutils}/bin/rm -f /run/niks3-server-url";
        };
        path = with pkgs; [
          tailscale
          jaq
          coreutils
        ];
        script = ''
          # Poll tailscale status until nix-controller peer appears
          CONTROLLER_IP=""
          while [ -z "$CONTROLLER_IP" ]; do
            CONTROLLER_IP=$(tailscale status --json 2>/dev/null \
              | jaq -r '.Peer | to_entries[] | select(.value.HostName == "nix-controller") | .value.TailscaleIPs[0] // empty' \
              | head -n1)
            if [ -z "$CONTROLLER_IP" ]; then
              echo "Waiting for nix-controller peer in Tailscale status..."
              sleep 15
            fi
          done
          echo "Found nix-controller at Tailscale IP: $CONTROLLER_IP"

          SERVER_URL="http://$CONTROLLER_IP:5751"
          echo "$SERVER_URL" > /run/niks3-server-url
          chmod 0444 /run/niks3-server-url
          echo "Wrote niks3 server URL: $SERVER_URL"

          # Keep running so that if tailscale peer disappears we can rediscover
          while true; do
            sleep 60
            NEW_IP=$(tailscale status --json 2>/dev/null \
              | jq -r '.Peer | to_entries[] | select(.value.HostName == "nix-controller") | .value.TailscaleIPs[0] // empty' \
              | head -n1)
            if [ -z "$NEW_IP" ]; then
              echo "WARNING: nix-controller no longer visible in Tailscale. Removing server URL..."
              rm -f /run/niks3-server-url
              # Rediscover
              CONTROLLER_IP=""
              while [ -z "$CONTROLLER_IP" ]; do
                CONTROLLER_IP=$(tailscale status --json 2>/dev/null \
                  | jq -r '.Peer | to_entries[] | select(.value.HostName == "nix-controller") | .value.TailscaleIPs[0] // empty' \
                  | head -n1)
                if [ -z "$CONTROLLER_IP" ]; then
                  echo "Waiting for nix-controller peer in Tailscale status..."
                  sleep 15
                fi
              done
              echo "Rediscovered nix-controller at: $CONTROLLER_IP"
              SERVER_URL="http://$CONTROLLER_IP:5751"
              echo "$SERVER_URL" > /run/niks3-server-url
              chmod 0444 /run/niks3-server-url
              echo "Updated niks3 server URL: $SERVER_URL"
            elif [ "$NEW_IP" != "$CONTROLLER_IP" ]; then
              echo "nix-controller IP changed from $CONTROLLER_IP to $NEW_IP, updating..."
              CONTROLLER_IP="$NEW_IP"
              SERVER_URL="http://$CONTROLLER_IP:5751"
              echo "$SERVER_URL" > /run/niks3-server-url
              chmod 0444 /run/niks3-server-url
              echo "Updated niks3 server URL: $SERVER_URL"
            fi
          done
        '';
      };

      # Healthcheck: verify niks3 is responding at the Tailscale IP URL
      cache-healthcheck = {
        description = "Check niks3 cache availability";
        after = [ "cache-tunnel.service" ];
        requires = [ "cache-tunnel.service" ];
        serviceConfig = {
          Type = "oneshot";
        };
        path = [
          pkgs.curl
          pkgs.coreutils
        ];
        script = ''
          FAIL_COUNT_FILE="/run/cache-healthcheck-failures"

          # Read the current niks3 server URL (written by cache-tunnel / controller-discovery)
          if [ ! -f /run/niks3-server-url ]; then
            echo "WARNING: /run/niks3-server-url does not exist; controller not yet discovered"
            exit 0
          fi

          NIKS3_URL=$(cat /run/niks3-server-url)

          if curl -s --max-time 10 -o /dev/null "$NIKS3_URL/"; then
            # Healthy — reset failure counter
            rm -f "$FAIL_COUNT_FILE"
            echo "niks3 is healthy at $NIKS3_URL"
          else
            # Failed — only remove URL file after 3 consecutive failures
            prev=$(cat "$FAIL_COUNT_FILE" 2>/dev/null || echo 0)
            count=$((prev + 1))
            echo "$count" > "$FAIL_COUNT_FILE"
            if [ "$count" -ge 3 ] && [ -f /run/niks3-server-url ]; then
              echo "WARNING: niks3 healthcheck failed $count times at $NIKS3_URL, disabling cache uploads"
              rm -f /run/niks3-server-url
            elif [ -f /run/niks3-server-url ]; then
              echo "WARNING: niks3 healthcheck failed ($count/3 before disabling) at $NIKS3_URL"
            fi
          fi
        '';
      };

      # Oneshot service that processes the cache upload queue
      # Triggered by path unit on new items; restart on failure with backoff
      cache-upload = {
        description = "Process cache upload queue";
        after = [
          "network-online.target"
          "cache-tunnel.service"
        ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${uploadScript}/bin/cache-upload";
          StateDirectory = "cache-upload-queue";
          Restart = "on-failure";
          RestartSec = "5min";
        };
        # Disable start limit — path unit triggers frequently during active builds
        # and that's expected. Only failure restarts should be rate-limited (via RestartSec).
        startLimitIntervalSec = 0;
      };

      # Prune uploaded path markers and re-enqueue the current system closure weekly
      cache-upload-prune = {
        description = "Prune cache upload done markers and re-enqueue system closure";
        serviceConfig = {
          Type = "oneshot";
        };
        path = [
          pkgs.nix
          pkgs.coreutils
        ];
        script = ''
          rm -rf ${queueDir}/done
          mkdir -p ${queueDir}/done ${queueDir}/pending

          echo "Re-enqueuing current system closure..."
          nix-store -qR /run/current-system | while IFS= read -r path; do
            [ -n "$path" ] || continue
            hash=$(basename "$path" | cut -d- -f1)
            echo "$path" > ${queueDir}/pending/"$hash"
          done
          echo "Done. $(ls ${queueDir}/pending | wc -l) paths queued."
        '';
      };
    };

    timers = {
      cache-status = {
        description = "Poll Hetzner Cloud cache status every 30s";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "10s";
          OnUnitActiveSec = "30s";
        };
      };

      cache-healthcheck = {
        description = "Periodic niks3 cache healthcheck";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "15s";
          OnUnitActiveSec = "30s";
        };
      };

      cache-upload = {
        description = "Retry cache uploads hourly";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "1h";
        };
      };

      cache-upload-prune = {
        description = "Prune cache upload done markers weekly";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
        };
      };
    };

    paths.cache-upload = {
      description = "Watch cache upload queue for new items";
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        DirectoryNotEmpty = "${queueDir}/pending";
        MakeDirectory = true;
      };
    };
  };

  # Enqueue locally-built paths for async upload to the cache
  nix.settings.post-build-hook = "${enqueueScript}";

  # SSH configuration for cache servers (user)
  home-manager.users.${config.username}.programs.ssh.matchBlocks = {
    "cache-*" = {
      user = "root";
      port = 3099;
      identityFile = "/root/.ssh/cache-key";
      proxyCommand = "${cacheProxyScript}/bin/hetzner-cache-proxy %h %p";
      extraOptions = {
        StrictHostKeyChecking = "yes";
        UserKnownHostsFile = "${cacheKnownHosts}";
        LogLevel = "ERROR";
        ConnectTimeout = "180";
      };
    };
  };

  # SSH configuration for cache servers (system-wide)
  programs.ssh.extraConfig = ''
    Host cache-*
      User root
      Port 3099
      IdentityFile /root/.ssh/cache-key
      ProxyCommand ${cacheProxyScript}/bin/hetzner-cache-proxy %h %p
      StrictHostKeyChecking yes
      UserKnownHostsFile ${cacheKnownHosts}
      LogLevel ERROR
      ConnectTimeout 180
  '';
}
