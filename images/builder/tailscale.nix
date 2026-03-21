{ pkgs, ... }:
{
  services.tailscale.enable = true;

  # Join headscale tailnet using the pre-auth key delivered via croc.
  # The key is minted client-side (by `builders create`) so the builder never
  # has access to the headscale API key.
  systemd.services.builder-tailscale-join = {
    description = "Join builder to headscale tailnet";
    after = [
      "secrets-ready.target"
      "tailscaled.service"
      "network-online.target"
    ];
    requires = [
      "secrets-ready.target"
      "tailscaled.service"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [
      tailscale
      jaq
      gnused
    ];
    script = ''
      WANT_SERVER="https://headscale.panfactumcf.com"
      AUTHKEY_FILE="/run/headscale-authkey"
      NAME_FILE="/run/builder-name"

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

      AUTHKEY=$(cat "$AUTHKEY_FILE")
      HOSTNAME=$(tr -d '[:space:]' < "$NAME_FILE" 2>/dev/null || echo "nix-builder")

      tailscale up \
        --login-server "$WANT_SERVER" \
        --authkey "$AUTHKEY" \
        --hostname "$HOSTNAME" \
        --accept-routes \
        --reset
    '';
  };

  # Deregister from headscale on shutdown. Since the node was registered as
  # ephemeral, logout causes headscale to remove it immediately — preventing
  # stale duplicate entries in the tailnet.
  systemd.services.tailscale-logout = {
    description = "Deregister from headscale before shutdown";
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${pkgs.tailscale}/bin/tailscale logout";
    };
  };
}
