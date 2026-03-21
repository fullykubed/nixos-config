_: {
  # niks3 binary cache service
  # Note: niks3 module is provided via flake input (niks3.nixosModules.default)
  # and imported at the flake level when building this configuration
  services.niks3 = {
    enable = true;
    httpAddr = "0.0.0.0:5751";

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

    gc = {
      enable = true;
      olderThan = "192h"; # 8 days
    };
  };

  systemd = {
    services = {
      niks3 = {
        after = [
          "secrets-ready.target"
          "controller-volume-mount.service"
          "controller-tailscale-join.service"
        ];
        requires = [
          "secrets-ready.target"
          "controller-volume-mount.service"
          "controller-tailscale-join.service"
        ];
        serviceConfig = {
          # Hardening — listens on 0.0.0.0:5751 (restricted to tailscale0 by firewall trustedInterfaces), reads secrets from /run, talks to PostgreSQL via unix socket
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

      # Ensure PostgreSQL starts after volume is mounted
      postgresql = {
        after = [ "controller-volume-mount.service" ];
        wants = [ "controller-volume-mount.service" ];
      };
    };

    # Ensure the secrets directory exists with proper permissions
    tmpfiles.rules = [
      "d /run/niks3-secrets 0700 niks3 niks3 - "
    ];
  };
}
