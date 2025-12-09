{ config, pkgs, ... }:
{

  users.users.${config.username} = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "scanner"
      "lp"
      "corectrl"
      "plugdev"
    ];
  };
  users.groups.${config.username}.members = [ config.username ];
}
