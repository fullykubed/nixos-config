{ config, pkgs, ... }:
{
  age.rekey = {
    hostPubkey = "/etc/ssh/ssh_host_ed25519_key.pub";
    masterIdentities = [
      ../../../yubikeys/yubikey_a_identity.pub
      ../../../yubikeys/yubikey_b_identity.pub
    ];
    storageMode = "local";
    localStorageDir = ./../../.. + "/secrets/rekeyed/${config.networking.hostName}";
  };

  environment.systemPackages = [ pkgs.agenix-rekey ];
}
