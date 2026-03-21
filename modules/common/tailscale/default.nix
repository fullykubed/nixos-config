{ config, pkgs, ... }:
let
  headscaleWrapped = pkgs.writeShellScriptBin "headscale" ''
    export HEADSCALE_CLI_ADDRESS="headscale.panfactumcf.com:443"
    export HEADSCALE_CLI_API_KEY
    HEADSCALE_CLI_API_KEY=$(cat ${config.age.secrets.headscale-api-key.path})
    TMPCONF=$(mktemp --suffix=.yaml)
    trap 'rm -f "$TMPCONF"' EXIT
    exec ${pkgs.headscale}/bin/headscale -c "$TMPCONF" "$@"
  '';
in
{
  age.secrets.headscale-api-key = {
    rekeyFile = ../../../secrets/headscale-api-key.age;
    path = "/run/agenix/headscale-api-key";
    mode = "0400";
    owner = "root";
  };

  environment.systemPackages = [
    pkgs.tailscale
    headscaleWrapped
  ];

  networking = {
    search = [ "ts.panfactumcf.com" ];
    firewall = {
      allowedUDPPorts = [ 41641 ];
      trustedInterfaces = [ "tailscale0" ];
    };
    dhcpcd.denyInterfaces = [ "tailscale0" ];
  };

  systemd = {
    packages = [ pkgs.tailscale ];

    services.tailscaled = {
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.procps
        pkgs.getent
        pkgs.kmod
      ];
      serviceConfig.Environment = [
        "PORT=41641"
        ''"FLAGS=--tun tailscale0"''
      ];
      # Keep tailscaled running across nixos-rebuild switches so active
      # connections aren't dropped
      stopIfChanged = false;
    };

    services.tailscale-autoconnect = {
      description = "Auto-join headscale tailnet";
      after = [
        "tailscaled.service"
        "network-online.target"
      ];
      wants = [
        "tailscaled.service"
        "network-online.target"
      ];
      wantedBy = [ "multi-user.target" ];
      partOf = [ "tailscaled.service" ];
      # Type=simple so systemd considers the unit "started" immediately
      # and doesn't block nixos-rebuild switch on API failures.
      serviceConfig = {
        Type = "simple";
        RemainAfterExit = true;
      };
      path = with pkgs; [
        tailscale
        curl
        jaq
      ];
      script = ''
        WANT_SERVER="https://headscale.panfactumcf.com"

        # Check current state and control URL
        status_json=$(tailscale status --json --peers=false 2>/dev/null || true)
        state=$(echo "$status_json" | jaq -r '.BackendState // empty')
        current_url=$(echo "$status_json" \
          | jaq -r '.Self.ControlURL // .ControlURL // empty' \
          | sed 's|/$||')

        if [[ "$state" == "Running" && "$current_url" == "$WANT_SERVER" ]]; then
          echo "Already connected to $WANT_SERVER"
          exit 0
        fi

        if [[ "$state" == "Running" && "$current_url" != "$WANT_SERVER" ]]; then
          echo "Connected to wrong server ($current_url) — logging out"
          tailscale logout
          sleep 2
        fi

        case "$state" in
          Running|NeedsLogin|NeedsMachineAuth|Stopped|"")
            echo "State=$state — authenticating against $WANT_SERVER"
            ;;
          *)
            echo "State=$state — waiting 5s for tailscaled"
            sleep 5
            ;;
        esac

        # Mint a fresh pre-auth key via headscale API
        API_KEY=$(cat /run/agenix/headscale-api-key)
        API_URL="https://headscale.panfactumcf.com/api/v1"

        # Look up numeric user ID for "default" (API requires uint64)
        USER_RESP=$(curl -s -w '\n%{http_code}' \
          -H "Authorization: Bearer $API_KEY" \
          "$API_URL/user")
        USER_HTTP=$(echo "$USER_RESP" | tail -1)
        USER_BODY=$(echo "$USER_RESP" | sed '$d')

        if [[ "$USER_HTTP" != "200" ]]; then
          echo "Failed to list users (HTTP $USER_HTTP)" >&2
          echo "Response: $USER_BODY" >&2
          exit 1
        fi

        echo "User list response: $USER_BODY"

        USER_ID=$(echo "$USER_BODY" \
          | jaq -r 'first(.. | objects | select(.name? == "default") | .id) // empty')

        if [[ -z "$USER_ID" ]]; then
          echo "User 'default' not found on headscale server" >&2
          echo "Create it on the controller: controller ssh --root -- headscale users create default" >&2
          exit 1
        fi

        echo "Resolved user 'default' to ID $USER_ID"

        EXPIRY=$(date -u -d '+2 hours' '+%Y-%m-%dT%H:%M:%SZ')
        RESPONSE=$(curl -s -w '\n%{http_code}' \
          -X POST \
          -H "Authorization: Bearer $API_KEY" \
          -H "Content-Type: application/json" \
          -d "{\"user\": $USER_ID, \"reusable\": false, \"expiration\": \"$EXPIRY\"}" \
          "$API_URL/preauthkey")

        HTTP_CODE=$(echo "$RESPONSE" | tail -1)
        BODY=$(echo "$RESPONSE" | sed '$d')

        if [[ "$HTTP_CODE" != "200" ]]; then
          echo "Headscale API returned HTTP $HTTP_CODE" >&2
          echo "Response: $BODY" >&2
          exit 1
        fi

        AUTHKEY=$(echo "$BODY" | jaq -r '.preAuthKey.key')

        if [[ -z "$AUTHKEY" || "$AUTHKEY" == "null" ]]; then
          echo "Failed to extract pre-auth key from response" >&2
          echo "Response: $BODY" >&2
          exit 1
        fi

        tailscale up \
          --login-server https://headscale.panfactumcf.com \
          --authkey "$AUTHKEY" \
          --hostname ${config.networking.hostName} \
          --accept-dns=false \
          --reset
      '';
    };
  };

  # Forward MagicDNS domains to Tailscale's resolver so device names
  # still resolve while dnscrypt-proxy handles everything else
  services.dnscrypt-proxy.settings.forwarding_rules = pkgs.writeText "tailscale-forwarding-rules" "ts.panfactumcf.com 100.100.100.100";
}
