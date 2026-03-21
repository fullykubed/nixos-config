{ pkgs, ... }:
let
  cloudflareAccountId = "f875b3b102f2a88a51db200ba95e1fc9";
in
{
  services = {
    # Headscale — self-hosted Tailscale control plane
    headscale = {
      enable = true;
      address = "127.0.0.1";
      port = 8080;
      settings = {
        server_url = "https://headscale.panfactumcf.com";
        dns = {
          base_domain = "ts.panfactumcf.com";
          magic_dns = true;
          nameservers.global = [ ];
          override_local_dns = false;
        };
        derp.server = {
          enabled = true;
          region_id = 999;
          region_code = "hel";
          region_name = "Helsinki";
          stun_listen_addr = "0.0.0.0:3478";
        };
        grpc_listen_addr = "127.0.0.1:50443";
        grpc_allow_insecure = true; # Caddy terminates TLS; loopback leg is h2c
        logtail.enabled = false;
        prefixes = {
          v4 = "100.64.0.0/10";
          v6 = "fd7a:115c:a1e0::/48";
        };
        noise.private_key_path = "/var/lib/headscale/noise_private.key";
      };
    };

    # Tailscale — controller joins its own headscale instance
    tailscale.enable = true;
  };

  systemd.services = {
    headscale = {
      after = [
        "secrets-ready.target"
        "controller-volume-mount.service"
      ];
      requires = [
        "secrets-ready.target"
        "controller-volume-mount.service"
      ];
      serviceConfig = {
        # Hardening — listens on localhost, writes state to /var/lib/headscale
        ProtectSystem = "strict";
        ReadWritePaths = [ "/var/lib/headscale" ];
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
    };

    # Create the headscale "default" user after the server is ready.
    # Waits for gRPC to respond, then creates the user idempotently.
    headscale-init = {
      description = "Create headscale default user";
      after = [ "headscale.service" ];
      requires = [ "headscale.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = with pkgs; [
        headscale
        jaq
      ];
      script = ''
        attempts=0
        until headscale users list >/dev/null 2>&1; do
          attempts=$((attempts + 1))
          if [ "$attempts" -ge 30 ]; then
            echo "Headscale not ready after 60 seconds" >&2
            exit 1
          fi
          echo "Waiting for headscale... (attempt $attempts/30)"
          sleep 2
        done

        if headscale users list -o json | jaq -e '.[] | select(.name == "default")' >/dev/null 2>&1; then
          echo "User 'default' already exists"
        else
          headscale users create default
          echo "Created user 'default'"
        fi
      '';
    };

    # Join the controller to its own headscale tailnet.
    # Creates a preauthkey via local CLI and runs tailscale up.
    controller-tailscale-join = {
      description = "Join controller to its own headscale tailnet";
      after = [
        "headscale-init.service"
        "tailscaled.service"
        "network-online.target"
      ];
      requires = [
        "headscale-init.service"
        "tailscaled.service"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = with pkgs; [
        headscale
        tailscale
        jaq
        gnused
      ];
      script = ''
        WANT_SERVER="https://headscale.panfactumcf.com"

        # Check if already connected to the right server
        status_json=$(tailscale status --json --peers=false 2>/dev/null || true)
        state=$(echo "$status_json" | jaq -r '.BackendState // empty')
        current_url=$(echo "$status_json" \
          | jaq -r '.Self.ControlURL // .ControlURL // empty' \
          | sed 's|/$||')

        if [ "$state" = "Running" ] && [ "$current_url" = "$WANT_SERVER" ]; then
          echo "Already connected to $WANT_SERVER"
          exit 0
        fi

        # Resolve numeric user ID for "default"
        USER_ID=$(headscale users list -o json | jaq -r '.[] | select(.name == "default") | .id')
        if [ -z "$USER_ID" ]; then
          echo "User 'default' not found" >&2
          exit 1
        fi

        # Create a single-use preauthkey and join
        AUTHKEY=$(headscale preauthkeys create --user "$USER_ID")
        tailscale up \
          --login-server "$WANT_SERVER" \
          --authkey "$AUTHKEY" \
          --hostname nix-controller \
          --accept-routes \
          --reset
      '';
    };

    # Update Cloudflare DNS A record and patch headscale DERP ipv4 on boot.
    # Runs after secrets-ready.target (which delivers the CF token via croc) and
    # before headscale (which needs the patched config).
    controller-dns-update = {
      description = "Update Cloudflare DNS and headscale DERP IP";
      after = [
        "secrets-ready.target"
        "controller-volume-mount.service"
        "network-online.target"
      ];
      requires = [
        "secrets-ready.target"
        "controller-volume-mount.service"
      ];
      wants = [ "network-online.target" ];
      before = [ "headscale.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Hardening — needs network for Cloudflare API and write access to
        # /etc/headscale to patch the generated config before headscale starts
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ "/etc/headscale" ];
      };
      path = with pkgs; [
        curl
        jaq
        gnused
      ];
      script = ''
        # Get public IP from Hetzner metadata
        PUBLIC_IP=$(curl -sf http://169.254.169.254/hetzner/v1/metadata/public-ipv4)

        # Update Cloudflare DNS A record
        CF_TOKEN=$(cat /run/cloudflare-dns-token)
        ZONE_ID=$(curl -sf -H "Authorization: Bearer $CF_TOKEN" \
          "https://api.cloudflare.com/client/v4/zones?account.id=${cloudflareAccountId}&name=panfactumcf.com" \
          | jaq -r '.result[0].id')
        RECORD=$(curl -sf -H "Authorization: Bearer $CF_TOKEN" \
          "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=headscale.panfactumcf.com" \
          | jaq -r '.result[0].id')
        if [ "$RECORD" = "null" ]; then
          curl -sf -X POST -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" \
            -d "{\"type\":\"A\",\"name\":\"headscale.panfactumcf.com\",\"content\":\"$PUBLIC_IP\",\"ttl\":60,\"proxied\":false}" \
            "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"
        else
          curl -sf -X PUT -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" \
            -d "{\"type\":\"A\",\"name\":\"headscale.panfactumcf.com\",\"content\":\"$PUBLIC_IP\",\"ttl\":60,\"proxied\":false}" \
            "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD"
        fi

        # Patch headscale DERP ipv4 in generated config
        sed -i "s/^\([ ]*\)stun_listen_addr:.*/&\n\1ipv4: $PUBLIC_IP/" /etc/headscale/config.yaml
      '';
    };
  };
}
