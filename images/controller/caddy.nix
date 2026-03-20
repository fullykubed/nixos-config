_: {
  # Caddy — TLS reverse proxy for headscale
  services.caddy = {
    enable = true;
    virtualHosts."headscale.panfactumcf.com".extraConfig = ''
      reverse_proxy http://localhost:8080
    '';
  };

  systemd.services.caddy = {
    after = [
      "cloud-init.service"
      "controller-volume-mount.service"
    ];
    wants = [
      "cloud-init.service"
      "controller-volume-mount.service"
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
