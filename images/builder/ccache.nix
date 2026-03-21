_: {
  imports = [ ../../modules/utility/ccache-r2.nix ];

  ccacheR2 = {
    accessKeyFile = "/run/ccache-r2-access-key";
    secretKeyFile = "/run/ccache-r2-secret-key";
    afterServices = [ "secrets-ready.target" ];
    waitForCredentials = true;
  };

  # Builder-specific: depend on secrets-ready for credential delivery
  systemd.services.ccache-r2-mount = {
    requires = [ "secrets-ready.target" ];
    wantedBy = [ "multi-user.target" ];
  };
}
