_: {
  imports = [ ../../modules/utility/ccache-r2.nix ];

  ccacheR2 = {
    accessKeyFile = "/run/ccache-r2-access-key";
    secretKeyFile = "/run/ccache-r2-secret-key";
    afterServices = [ "cloud-init.service" ];
    waitForCredentials = true;
  };

  # Builder-specific: depend on cloud-init for credential delivery
  # NOT wantedBy — started by cloud-init runcmd
  systemd.services.ccache-r2-mount.wants = [ "cloud-init.service" ];
}
