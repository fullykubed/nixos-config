_: {
  # SSH server configuration
  # Host key is injected via croc-based secret transfer; disable auto-generation
  # so we use a known key that the client can verify.
  services.openssh = {
    enable = true;
    ports = [ 3098 ];
    hostKeys = [ ]; # croc-receive writes our static host key before sshd starts
    extraConfig = "HostKey /etc/ssh/ssh_host_ed25519_key";
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

  # cloud-init for bootstrap data delivery (croc relay password and croc code)
  services.cloud-init = {
    enable = true;
    network.enable = true;
  };

  # Prevent cloud-init from generating SSH host keys (we inject our own via user-data)
  environment.etc."cloud/cloud.cfg.d/99-no-ssh-keygen.cfg".text = ''
    ssh_genkeytypes: []
    ssh_deletekeys: false
  '';

  # Ensure sshd starts after croc-receive has installed the host key
  systemd.services.sshd = {
    after = [ "secrets-ready.target" ];
    requires = [ "secrets-ready.target" ];
  };

  # Firewall — no public inbound ports; SSH is reachable only via Tailscale
  # (tailscale0 is a trustedInterface, set in the tailscale module)
  networking.firewall.enable = true;
}
