# ccache compiler cache with Cloudflare R2 backend
#
# Thin wrapper around the shared ccache-R2 utility module that sets credential
# paths from agenix, declares the encrypted secret files, and adds the
# nix-ccache setgid wrapper for manual cache inspection.
{ config, pkgs, ... }:
{
  imports = [ ../../utility/ccache-r2.nix ];

  ccacheR2 = {
    accessKeyFile = config.age.secrets.ccache-r2-access-key.path;
    secretKeyFile = config.age.secrets.ccache-r2-secret-key.path;
    afterServices = [ "agenix.service" ];
    waitForCredentials = false;
  };

  age.secrets = {
    ccache-r2-access-key = {
      rekeyFile = ../../../secrets/ccache-r2-access-key.age;
      path = "/run/agenix/ccache-r2-access-key";
      mode = "0400";
      owner = "root";
    };
    ccache-r2-secret-key = {
      rekeyFile = ../../../secrets/ccache-r2-secret-key.age;
      path = "/run/agenix/ccache-r2-secret-key";
      mode = "0400";
      owner = "root";
    };
  };

  security.wrappers.nix-ccache = {
    owner = "root";
    group = "nixbld";
    setuid = false;
    setgid = true;
    source = pkgs.writeScript "nix-ccache" ''
      #!${pkgs.runtimeShell}
      exec ${pkgs.ccache}/bin/ccache -d /var/cache/ccache "$@"
    '';
  };

  # Start mount at boot (builders start it via cloud-init runcmd instead)
  systemd.services.ccache-r2-mount.wantedBy = [ "multi-user.target" ];
}
