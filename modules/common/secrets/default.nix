{ config, pkgs, ... }:
{
  age.rekey = {
    hostPubkey = builtins.readFile ../../../secrets/machines/${config.networking.hostName}/ssh-host-key.pub;
    masterIdentities = [
      ../../../yubikeys/yubikey_a_identity.pub
      ../../../yubikeys/yubikey_b_identity.pub
    ];
    storageMode = "local";
    localStorageDir = ./../../.. + "/secrets/rekeyed/${config.networking.hostName}";
  };

  age.secrets.ssh-host-key = {
    rekeyFile = ./../../.. + "/secrets/machines/${config.networking.hostName}/ssh-host-key.age";
    path = "/etc/ssh/ssh_host_ed25519_key";
    symlink = false;
    owner = "root";
    group = "root";
    mode = "0600";
  };

  environment.systemPackages = [ pkgs.agenix-rekey ];
}
