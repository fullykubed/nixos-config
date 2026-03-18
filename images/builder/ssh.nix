_: {
  # SSH server configuration
  # Host key is injected via cloud-init; disable auto-generation so we use
  # a known key that the client can verify.
  services.openssh = {
    enable = true;
    ports = [ 3098 ];
    hostKeys = [ ]; # Cloud-init writes our static host key before sshd starts
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

  # Cloud-init for SSH key and host key injection
  services.cloud-init = {
    enable = true;
    network.enable = true;
  };

  # Prevent cloud-init from generating SSH host keys (we inject our own via user-data)
  environment.etc."cloud/cloud.cfg.d/99-no-ssh-keygen.cfg".text = ''
    ssh_genkeytypes: []
    ssh_deletekeys: false
  '';

  # Ensure sshd starts after cloud-config writes the host key via write_files
  # (cloud-init.service only fetches user-data; cloud-config.service applies it)
  systemd.services.sshd = {
    after = [ "cloud-config.service" ];
    wants = [ "cloud-config.service" ];
  };

  # Firewall - only SSH
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 3098 ];
  };
}
