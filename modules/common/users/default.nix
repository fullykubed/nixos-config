{
  config,
  pkgs,
  lib,
  ...
}:
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
    openssh.authorizedKeys.keys = [
      (lib.strings.trim (builtins.readFile ../../../secrets/remote-access-ssh-key.pub))
    ];
  };
  users.groups.${config.username}.members = [ config.username ];
}
