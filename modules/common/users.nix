{ config, pkgs, ... }:
{

  users.users.${config.username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "scanner"
      "lp"
      "corectrl"
      "plugdev"
    ];
  };
  users.groups.jack.members = [ "jack" ];
}
