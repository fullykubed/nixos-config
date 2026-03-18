{ pkgs, ... }:
{
  imports = [ ./hardware.nix ];

  # System identification
  networking.hostName = "nix-cache";
  system.stateVersion = "24.05";

  services = {
    # niks3 binary cache service
    # Note: niks3 module is provided via flake input (niks3.nixosModules.default)
    # and imported at the flake level when building this configuration
    niks3 = {
      enable = true;
      httpAddr = "127.0.0.1:5751";

      # Auto-configure PostgreSQL locally
      database.createLocally = true;

      # S3 backend configuration (Cloudflare R2)
      # The account ID placeholder will be replaced via cloud-init or manual config
      s3 = {
        endpoint = "f875b3b102f2a88a51db200ba95e1fc9.r2.cloudflarestorage.com";
        bucket = "fullykubed-nixos-cache";
        useSSL = true;
        accessKeyFile = "/run/niks3-secrets/r2-access-key";
        secretKeyFile = "/run/niks3-secrets/r2-secret-key";
      };

      # API authentication token for write operations
      apiTokenFile = "/run/niks3-secrets/api-token";

      # NAR signing keys
      signKeyFiles = [ "/run/niks3-secrets/signing-key" ];

      # Disable automatic garbage collection
      # GC will be managed manually or via separate mechanism
      gc.enable = false;
    };

    # SSH server configuration
    # Host key is injected via cloud-init; disable auto-generation so we use
    # a known key that clients can verify.
    openssh = {
      enable = true;
      ports = [ 3099 ];
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

    # Cloud-init for SSH key and secrets injection
    cloud-init = {
      enable = true;
      network.enable = true;
    };
  };

  # Prevent cloud-init from generating SSH host keys (we inject our own via user-data)
  environment.etc."cloud/cloud.cfg.d/99-no-ssh-keygen.cfg".text = ''
    ssh_genkeytypes: []
    ssh_deletekeys: false
  '';

  # Ensure services start after cloud-init writes secrets
  systemd = {
    services = {
      sshd = {
        after = [ "cloud-init.service" ];
        wants = [ "cloud-init.service" ];
      };

      niks3 = {
        after = [ "cloud-init.service" ];
        wants = [ "cloud-init.service" ];
        serviceConfig = {
          # Hardening — listens on localhost, reads secrets from /run, talks to PostgreSQL via unix socket
          ProtectSystem = "strict";
          ReadWritePaths = [ "/run/niks3-secrets" ];
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          PrivateDevices = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
            "@network-io"
          ];
          SystemCallArchitectures = "native";
        };
      };
    };

    # Ensure the secrets directory exists with proper permissions
    tmpfiles.rules = [
      "d /run/niks3-secrets 0700 niks3 niks3 - "
    ];
  };

  users = {
    mutableUsers = false;
    allowNoPasswordLogin = true;

    # Admin user for SSH access
    users.admin = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      shell = pkgs.bash;
      home = "/home/admin";
      createHome = true;
      openssh.authorizedKeys.keys = [
        # Injected via cloud-init user-data
      ];
    };
  };

  # Allow passwordless sudo for admin user
  security.sudo.wheelNeedsPassword = false;

  # Nix daemon configuration
  nix = {
    settings = {
      trusted-users = [
        "root"
        "admin"
      ];
      extra-experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
    gc = {
      automatic = false;
    };
  };

  # Essential packages for management
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    htop
    hcloud
    jaq
    cloud-init
    postgresql # For manual DB queries
  ];

  # Firewall - SSH only; niks3 write API is accessed via SSH tunnel
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      3099 # SSH
    ];
  };

  # Cache doesn't need user namespaces (builder does for nix sandboxing)
  boot.kernel.sysctl."user.max_user_namespaces" = 0;

  # Disable unnecessary services to reduce attack surface
  documentation.enable = false;
  programs.command-not-found.enable = false;
}
