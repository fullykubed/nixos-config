{ pkgs, ... }:
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
          nameservers.global = [
            "1.1.1.1"
            "9.9.9.9"
          ];
        };
        derp.server = {
          enabled = true;
          region_id = 999;
          region_code = "hel";
          region_name = "Helsinki";
          stun_listen_addr = "0.0.0.0:3478";
        };
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
        "cloud-init.service"
        "controller-volume-mount.service"
      ];
      wants = [
        "cloud-init.service"
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

    # Update Cloudflare DNS A record and patch headscale DERP ipv4 on boot.
    # Runs after cloud-init (which writes the CF token) and before headscale
    # (which needs the patched config).
    controller-dns-update = {
      description = "Update Cloudflare DNS and headscale DERP IP";
      after = [
        "cloud-init.service"
        "controller-volume-mount.service"
        "network-online.target"
      ];
      wants = [
        "network-online.target"
        "controller-volume-mount.service"
      ];
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
        jq
        gnused
      ];
      script = ''
        # Get public IP from Hetzner metadata
        PUBLIC_IP=$(curl -sf http://169.254.169.254/hetzner/v1/metadata/public-ipv4)

        # Update Cloudflare DNS A record
        CF_TOKEN=$(cat /run/cloudflare-dns-token)
        ZONE_ID=$(curl -sf -H "Authorization: Bearer $CF_TOKEN" \
          "https://api.cloudflare.com/client/v4/zones?name=panfactumcf.com" \
          | jq -r '.result[0].id')
        RECORD=$(curl -sf -H "Authorization: Bearer $CF_TOKEN" \
          "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=headscale.panfactumcf.com" \
          | jq -r '.result[0].id')
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
