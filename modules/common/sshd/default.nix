{ config, pkgs, ... }:
{
  services.openssh = {
    enable = true;
    openFirewall = false;
    listenAddresses = [
      {
        addr = "127.0.0.1";
        port = 22;
      }
    ];
    settings = {
      PermitRootLogin = "no";
    };
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        rounds = 256;
        type = "ed25519";
      }
    ];
  };
}
