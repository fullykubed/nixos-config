{ config, pkgs, ... }:
{
  age = {
    rekey = {
      hostPubkey = "/etc/ssh/ssh_host_ed25519_key.pub";
      masterIdentities = [
        ../../yubikeys/yubikey_a_identity.pub
        ../../yubikeys/yubikey_b_identity.pub
      ];
      storageMode = "local";
      localStorageDir = ./../.. + "/secrets/rekeyed/${config.networking.hostName}";
    };

    #   secrets = {
    #     syncthing-pixel6-id = {
    #         rekeyFile = ../secrets/syncthing-pixel6-id.age;
    #     };
    #   };
  };

  environment.systemPackages = [ pkgs.agenix-rekey ];

}
