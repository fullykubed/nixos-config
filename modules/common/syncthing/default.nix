{ config, ... }:
{
  imports = [ ../../utility/syncthing.nix ];

  syncthing = {
    user = config.username;
    group = config.username;
    dataDir = config.homeDir;
  };

  age.secrets.syncthing-key = {
    rekeyFile = ./../../.. + "/secrets/machines/${config.networking.hostName}/syncthing-key.age";
    owner = config.username;
    group = config.username;
    mode = "0400";
  };

  age.secrets.syncthing-cert = {
    rekeyFile = ./../../.. + "/secrets/machines/${config.networking.hostName}/syncthing-cert.age";
    owner = config.username;
    group = config.username;
    mode = "0400";
  };

  services.syncthing.key = config.age.secrets.syncthing-key.path;
  services.syncthing.cert = config.age.secrets.syncthing-cert.path;
}
