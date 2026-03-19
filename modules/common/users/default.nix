{
  config,
  pkgs,
  lib,
  ...
}:
{

  users = {
    allowNoPasswordLogin = true;
    users.${config.username} = {
      isNormalUser = true;
      hashedPassword = "!";
      shell = pkgs.zsh;
      extraGroups = [
        "scanner"
        "lp"
        "corectrl"
        "plugdev"
        "systemd-journal"
      ];
      openssh.authorizedKeys.keys = [
        (lib.strings.trim (builtins.readFile ../../../secrets/remote-access-ssh-key.pub))
      ];
    };
    users.root = {
      hashedPassword = "!";
    };
    groups.${config.username}.members = [ config.username ];
  };
}
