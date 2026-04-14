{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Controller host public key for SSH
  controllerHostPublicKey = builtins.readFile ../../../secrets/cache-host-key.pub;

  # Known hosts file for SSH host key verification
  cacheKnownHosts = pkgs.writeText "controller-known-hosts" (
    let
      hostKey = lib.removeSuffix "\n" controllerHostPublicKey;
    in
    "nix-controller ${hostKey}\n"
  );

  # CLI tool for managing the controller server
  controllerCli = pkgs.writeShellApplication {
    name = "controller";
    runtimeInputs = [
      pkgs.hcloud
      pkgs.jaq
      pkgs.bc
      pkgs.ncurses
      pkgs.nix
      pkgs.openssh
      pkgs.sqlite
    ];
    text = builtins.readFile ./controller-cli.sh;
  };

  # niks3 server URL — controller is reachable via Tailscale MagicDNS
  niks3Url = "http://nix-controller:5751";

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

  # Controller status collection script (runs as root via systemd)
  controllerStatusScript = pkgs.writeShellApplication {
    name = "controller-status";
    runtimeInputs = [
      pkgs.hcloud
      pkgs.jaq
      pkgs.curl
      pkgs.coreutils
      pkgs.openssh
    ];
    text = builtins.readFile ./controller-status.sh;
  };

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
      controllerCli
      pkgs.hcloud # Hetzner Cloud CLI
      pkgs.bc # Calculator for cost estimation
      pkgs.socat # For controller CLI SSH connections
      pkgs.hcloud-upload-image # Upload custom images to Hetzner Cloud
      pkgs.niks3-cli # For pushing build results to cache
      pkgs.croc # File transfer tool (uses private relay)
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

  # home-manager config for both root and the logged-in user
  home-manager = {
    # Token-injecting wrappers for interactive root use
    users.root.home.packages = [
      hcloudWrapped
      hcloudUploadImageWrapped
    ];

    users.${config.username} = {
      # croc alias: use private relay on the controller by default
      programs.zsh.shellAliases = {
        croc = ''croc --relay headscale.panfactumcf.com:19009 --pass "$(cat /run/agenix/croc-relay-password)"'';
      };

      # SSH configuration for controller (user) — connects via Tailscale
      programs.ssh.matchBlocks = {
        "nix-controller" = {
          user = "root";
          port = 3099;
          identityFile = "/root/.ssh/cache-key";
          extraOptions = {
            StrictHostKeyChecking = "yes";
            UserKnownHostsFile = "${cacheKnownHosts}";
            LogLevel = "ERROR";
          };
        };
      };
    };
  };

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
    headscale-noise-key = {
      rekeyFile = ../../../secrets/headscale-noise-key.age;
      path = "/run/agenix/headscale-noise-key";
      mode = "0400";
      owner = "root";
    };
    controller-volume-key = {
      rekeyFile = ../../../secrets/controller-volume-key.age;
      path = "/run/agenix/controller-volume-key";
      mode = "0400";
      owner = "root";
    };
    croc-relay-password = {
      rekeyFile = ../../../secrets/croc-relay-password.age;
      path = "/run/agenix/croc-relay-password";
      mode = "0444";
      owner = "root";
    };
  };

  systemd = {
    services = {
      # Oneshot service that processes the cache upload queue
      # Triggered by path unit on new items; restart on failure with backoff
      cache-upload = {
        description = "Process cache upload queue";
        after = [
          "network-online.target"
          "nss-lookup.target"
          "tailscale-autoconnect.service"
        ];
        wants = [
          "network-online.target"
          "nss-lookup.target"
          "tailscale-autoconnect.service"
        ];
        # Don't let nixos-rebuild switch block waiting for an in-progress upload.
        # The path unit and timer will trigger new runs as needed.
        restartIfChanged = false;
        reloadIfChanged = true;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${uploadScript}/bin/cache-upload";
          StateDirectory = "cache-upload-queue";
          Environment = "NIKS3_SERVER_URL=${niks3Url}";
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
        unitConfig.OnSuccess = "cache-upload.service";
        serviceConfig = {
          Type = "oneshot";
        };
        path = [
          controllerCli
          pkgs.coreutils
        ];
        script = ''
          rm -rf ${queueDir}/done
          mkdir -p ${queueDir}/done ${queueDir}/pending

          echo "Re-enqueuing full build closure..."
          controller cache build-closure 2>/dev/null | while IFS= read -r path; do
            [ -n "$path" ] || continue
            hash=$(basename "$path" | cut -d- -f1)
            echo "$path" > ${queueDir}/pending/"$hash"
          done

          echo "Done. $(ls ${queueDir}/pending | wc -l) paths queued."
        '';
      };

      controller-status = {
        description = "Collect controller VM status for waybar";
        restartIfChanged = false;
        reloadIfChanged = true;
        after = [
          "network-online.target"
          "nss-lookup.target"
        ];
        wants = [
          "network-online.target"
          "nss-lookup.target"
        ];
        serviceConfig = {
          Type = "oneshot";
          RuntimeDirectory = "controller-status";
          RuntimeDirectoryPreserve = "yes";
        };
        path = [ controllerStatusScript ];
        script = ''
          export HCLOUD_TOKEN
          HCLOUD_TOKEN=$(cat ${tokenPath})
          controller-status
        '';
      };
    };

    timers = {
      cache-upload = {
        description = "Retry cache uploads hourly";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "1h";
        };
      };

      cache-upload-prune = {
        description = "Prune cache upload done markers daily";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };

      controller-status = {
        description = "Poll controller VM status every 60 seconds";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "15s";
          OnUnitActiveSec = "60s";
        };
      };
    };

    # Write static niks3 URL for consumers that check this file (waybar, upload daemon)
    tmpfiles.rules = [
      "f /run/niks3-server-url 0444 root root - ${niks3Url}"
    ];

    paths.cache-upload = {
      description = "Watch cache upload queue for new items";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-tmpfiles-setup.service" ];
      pathConfig = {
        DirectoryNotEmpty = "${queueDir}/pending";
        MakeDirectory = true;
      };
    };
  };

  # Enqueue locally-built paths for async upload to the cache
  nix.settings.post-build-hook = "${enqueueScript}";

  # SSH configuration for controller (system-wide) — connects via Tailscale
  programs.ssh.extraConfig = ''
    Host nix-controller
      User root
      Port 3099
      IdentityFile /root/.ssh/cache-key
      StrictHostKeyChecking yes
      UserKnownHostsFile ${cacheKnownHosts}
      LogLevel ERROR
  '';
}
