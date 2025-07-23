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

    # Forward DNS requests to stubby
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

  # Stubby enables system-wide DNS-over-TLS to privacy-focused
  # DNS resolvers
  services.stubby = {
    enable = true;
    settings = pkgs.stubby.passthru.settingsExample // {
      listen_addresses = [ "127.0.0.1" ];
      dnssec_return_status = "GETDNS_EXTENSION_TRUE";
      tls_authentication = "GETDNS_AUTHENTICATION_REQUIRED";
      dns_transport_list = [ "GETDNS_TRANSPORT_TLS" ];
      resolution_type = "GETDNS_RESOLUTION_STUB";

      # To get the updated key, run:
      # echo | openssl s_client -connect '<insert_ip_address>:853' 2>/dev/null | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
      upstream_recursive_servers = [
        {
          address_data = "194.242.2.2";
          tls_auth_name = "dns.mullvad.net";
          tls_pubkey_pinset = [
            {
              digest = "sha256";
              value = "g8bfYNSxU86c8odFPsdTvWnC2VZkxIiHLZ2a6pydEjI=";
            }
          ];
        }
        {
          address_data = "9.9.9.9";
          tls_auth_name = "dns.quad9.net";
          tls_pubkey_pinset = [
            {
              digest = "sha256";
              value = "i2kObfz0qIKCGNWt7MjBUeSrh0Dyjb0/zWINImZES+I=";
            }
          ];
        }
      ];
    };
  };
}
