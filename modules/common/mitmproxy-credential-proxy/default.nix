{
  config,
  pkgs,
  ...
}:
let
  # Credential mappings - add new entries here for additional services
  credentialMappings = [
    {
      domain = "api.github.com";
      header = "Authorization";
      value_prefix = "Bearer ";
      secret_path = config.age.secrets.github-token.path;
    }
  ];

  credentialConfig = pkgs.writeText "credential-mappings.json" (builtins.toJSON credentialMappings);

  credentialProxy = pkgs.callPackage ./proxy { };
in
{
  users.users.mitmproxy-credential-proxy = {
    isSystemUser = true;
    group = "mitmproxy-credential-proxy";
    home = "/var/lib/mitmproxy-credential-proxy";
  };

  users.groups.mitmproxy-credential-proxy = { };

  age.secrets = {
    github-token = {
      rekeyFile = ../../../secrets/github-token.age;
      mode = "0400";
      owner = "mitmproxy-credential-proxy";
    };
  };

  systemd.services.mitmproxy-credential-proxy = {
    description = "Credential injection MITM proxy";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      User = "mitmproxy-credential-proxy";
      Group = "mitmproxy-credential-proxy";
      StateDirectory = "mitmproxy-credential-proxy";
      ExecStart = "${credentialProxy}/bin/credential-proxy";
      Restart = "on-failure";
      RestartSec = 5;
    };

    environment = {
      CREDENTIAL_PROXY_CONFIG = "${credentialConfig}";
      CREDENTIAL_PROXY_STATE_DIR = "/var/lib/mitmproxy-credential-proxy";
    };
  };
}
