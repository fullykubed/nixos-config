{ pkgs, ... }:
{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraUpFlags = [ "--accept-dns=false" ];
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Forward MagicDNS domains to Tailscale's resolver so device names
  # still resolve while dnscrypt-proxy handles everything else
  services.dnscrypt-proxy.settings.forwarding_rules = pkgs.writeText "tailscale-forwarding-rules" "ts.net 100.100.100.100";
}
