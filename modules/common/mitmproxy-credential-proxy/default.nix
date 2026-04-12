{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Credential mappings - add new entries here for additional services
  credentialMappings = [
    {
      domain = "api.github.com";
      header = "Authorization";
      value_prefix = "token ";
      secret_path = config.age.secrets.github-token.path;
    }
  ];

  credentialConfig = pkgs.writeText "credential-mappings.json" (builtins.toJSON credentialMappings);

  credentialProxy = pkgs.callPackage ./proxy { };

  stateDir = "/var/lib/mitmproxy-credential-proxy";
in
{
  config = lib.mkIf (config.deviceType != "remote-builder") {
    users.users.mitmproxy-credential-proxy = {
      isSystemUser = true;
      group = "mitmproxy-credential-proxy";
      home = stateDir;
    };
  
    users.groups.mitmproxy-credential-proxy = { };
  
    age.secrets = {
      github-token = {
        rekeyFile = ../../../secrets/github-token.age;
        mode = "0400";
        owner = "mitmproxy-credential-proxy";
      };
      credential-proxy-ca-key = {
        rekeyFile = ../../../secrets/credential-proxy-ca-key.age;
        mode = "0400";
        owner = "mitmproxy-credential-proxy";
      };
    };
  
    systemd.services.mitmproxy-credential-proxy = {
      description = "Credential injection MITM proxy";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "nss-lookup.target"
      ];
      wants = [
        "network-online.target"
        "nss-lookup.target"
      ];
  
      serviceConfig = {
        Type = "simple";
        User = "mitmproxy-credential-proxy";
        Group = "mitmproxy-credential-proxy";
        StateDirectory = "mitmproxy-credential-proxy";
        ExecStartPre = pkgs.writeShellScript "credential-proxy-setup-ca" ''
          cp ${./ca-cert.pem} ${stateDir}/mitmproxy-ca-cert.pem
          cp ${config.age.secrets.credential-proxy-ca-key.path} ${stateDir}/ca-key.pem
          chmod 644 ${stateDir}/mitmproxy-ca-cert.pem
          chmod 600 ${stateDir}/ca-key.pem
        '';
        ExecStart = "${credentialProxy}/bin/credential-proxy";
        Restart = "on-failure";
        RestartSec = 5;
      };
  
      environment = {
        CREDENTIAL_PROXY_CONFIG = "${credentialConfig}";
        CREDENTIAL_PROXY_STATE_DIR = stateDir;
      };
    };
  
    security.pki.certificateFiles = [
      ./ca-cert.pem
    ];
  };
}
