_: {
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
