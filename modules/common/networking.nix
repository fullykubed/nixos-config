{ config, pkgs, ... }:
{
  networking = {
    networkmanager = {
      enable = true;

      # Use our custom configuration for DNS
      dns = "none";
    };

    # Disable wpa_supplicant as we are using network manager
    wireless.enable = false;

    hosts = {
      # Fixes dns lookups at local host addresses
      # https://github.com/NixOS/nix/issues/5441
      "127.0.0.1" = [ "this.pre-initializes.the.dns.resolvers.invalid." ];
    };

    # Forward DNS requests to dnscrypt-proxy2
    nameservers = [ "127.0.0.1" ];

    firewall = {
      enable = true;

      # Enable the wireguard port
      allowedUDPPorts = [ 51820 ];

      # if packets are still dropped, they will show up in dmesg
      logReversePathDrops = true;
    };
    # Ensures that network manager manages the DNS
    enableIPv6 = false;
  };

  services.resolved.enable = false;

  # dnscrypt-proxy2 enables system-wide DNS-over-HTTPS and DNSCrypt
  # to privacy-focused DNS resolvers
  services.dnscrypt-proxy2 = {
    enable = true;
    settings = {
      listen_addresses = [ "127.0.0.1:53" ];

      # Use servers that support DNSSEC and don't log queries
      server_names = [
        "mullvad-base-doh"
        "quad9-doh-ip4-port443-filter-pri"
      ];

      # Load balancing strategy
      lb_strategy = "random";

      # Enable DNSSEC validation
      require_dnssec = true;

      # Use DNS-over-HTTPS
      doh_servers = true;

      # Enable HTTP/3 (QUIC) support for faster connections
      http3 = true;

      # Require servers that don't log
      require_nolog = true;

      # Require servers that don't filter
      require_nofilter = false;

      # Use system trust store for certificate validation
      tls_disable_session_tickets = true;

      # Cache settings
      cache = true;
      cache_size = 4096;
      cache_min_ttl = 2400;
      cache_max_ttl = 86400;
      cache_neg_min_ttl = 30;
      cache_neg_max_ttl = 30;

      # Bootstrap resolvers for initial connection
      bootstrap_resolvers = [
        "9.9.9.9:53"
        "194.242.2.2:53"
      ];

      # Fallback resolvers
      fallback_resolvers = [
        "9.9.9.9:53"
        "194.242.2.2:53"
      ];
      ignore_system_dns = true;

      # Enable query logging
      query_log = {
        file = "/var/log/dnscrypt-proxy/query.log";
        format = "tsv";
      };

      # TODO: Enable monitoring UI in next NixOS release
      # The monitoring_ui option is not yet available in NixOS stable
      # Uncomment after upgrading to a newer release
      # monitoring_ui = {
      #   enabled = true;
      #   username = "";
      #   tls_certificate = "";
      #   tls_key = "";
      #   privacy_level = 1;
      #   listen_address = "127.0.0.1:8053";
      #   enable_query_log = true;
      # };

      # Sources for server lists
      sources = {
        public-resolvers = {
          urls = [
            "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
            "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
          ];
          cache_file = "/var/lib/dnscrypt-proxy2/public-resolvers.md";
          minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
        };
      };
    };
  };
}
