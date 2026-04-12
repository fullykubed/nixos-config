{ config, lib, ... }:
{
  config = lib.mkMerge [
    {
      services.openssh = {
        enable = true;
        openFirewall = false;
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PubkeyAuthentication = true;
          PermitEmptyPasswords = false;
          MaxAuthTries = 3;
          MaxSessions = 2;
          X11Forwarding = false;
        };
        extraConfig = ''
          LoginGraceTime 30
          MaxStartups 10:30:100
          ClientAliveInterval 300
          ClientAliveCountMax 2
          TCPKeepAlive no
          AllowTcpForwarding no
          AllowAgentForwarding no
          HostbasedAuthentication no
          AuthenticationMethods publickey
        '';
        hostKeys = [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            rounds = 256;
            type = "ed25519";
          }
        ];
      };
    }

    (lib.mkIf (config.deviceType == "remote-builder") {
      services.openssh = {
        ports = lib.mkForce [ 3098 ];
        hostKeys = lib.mkForce [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
        settings = {
          PermitRootLogin = lib.mkForce "prohibit-password";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          X11Forwarding = false;
          AllowAgentForwarding = false;
          AllowTcpForwarding = lib.mkForce "local";
          MaxSessions = lib.mkForce 10;
          MaxAuthTries = 3;
          LoginGraceTime = 30;
          LogLevel = "VERBOSE";
          Ciphers = [ "chacha20-poly1305@openssh.com" ];
          KexAlgorithms = [ "sntrup761x25519-sha512@openssh.com" ];
          Macs = [ "hmac-sha2-512-etm@openssh.com" ];
        };
        extraConfig = lib.mkForce "";
      };

      age.secrets.builder-host-key = {
        rekeyFile = ../../../secrets/builder-host-key.age;
        path = lib.mkForce "/etc/ssh/ssh_host_ed25519_key";
        mode = "0400";
      };
    })
  ];
}
