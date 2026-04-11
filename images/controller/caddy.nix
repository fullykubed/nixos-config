_: {
  # Caddy — TLS reverse proxy for headscale
  services.caddy = {
    enable = true;
    virtualHosts."headscale.panfactumcf.com".extraConfig = ''
      @grpc header Content-Type application/grpc*
      reverse_proxy @grpc h2c://localhost:50443
      reverse_proxy http://localhost:8080
    '';
  };

  systemd.services.caddy = {
    after = [
      "secrets-ready.target"
      "controller-volume-mount.service"
      "controller-dns-update.service"
      "network-online.target"
      "nss-lookup.target"
    ];
    requires = [
      "secrets-ready.target"
      "controller-volume-mount.service"
      "controller-dns-update.service"
    ];
    wants = [
      "network-online.target"
      "nss-lookup.target"
    ];
    serviceConfig = {
      # Hardening — binds to 80/443, reads TLS certs from /var/lib/caddy
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/caddy" ];
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
}
