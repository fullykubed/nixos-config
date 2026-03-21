_: {
  config = {
    services = {
      openssh = {
        enable = true;
        ports = [ 3099 ];
        hostKeys = [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
        settings = {
          PermitRootLogin = "prohibit-password";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          X11Forwarding = false;
          AllowAgentForwarding = false;
          AllowTcpForwarding = "local";
          MaxAuthTries = 3;
          LoginGraceTime = 30;
          MaxSessions = 10;
          LogLevel = "VERBOSE";
          Ciphers = [ "chacha20-poly1305@openssh.com" ];
          KexAlgorithms = [ "sntrup761x25519-sha512@openssh.com" ];
          Macs = [ "hmac-sha2-512-etm@openssh.com" ];
        };
      };

      # Cloud-init for network configuration and croc bootstrap payload
      cloud-init = {
        enable = true;
        network.enable = true;
      };
    };

    networking.firewall.allowedTCPPorts = [ 3099 ];

    # Prevent cloud-init from generating SSH host keys (NixOS handles it)
    environment.etc."cloud/cloud.cfg.d/99-no-ssh-keygen.cfg".text = ''
      ssh_genkeytypes: []
      ssh_deletekeys: false
    '';

    # Restart sshd after croc delivers the real host key
    systemd.services.sshd-restart-on-secrets = {
      description = "Restart sshd after secrets delivery";
      after = [
        "secrets-ready.target"
        "sshd.service"
      ];
      requires = [ "secrets-ready.target" ];
      wantedBy = [ "secrets-ready.target" ];
      serviceConfig.Type = "oneshot";
      script = "systemctl restart sshd.service";
    };
  };
}
