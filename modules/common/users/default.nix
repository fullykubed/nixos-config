{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkMerge [
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

    (lib.mkIf (config.deviceType == "remote-builder") {
      users.users.remotebuild = {
        isSystemUser = true;
        group = "remotebuild";
        home = "/var/lib/remotebuild";
        createHome = true;
        shell = "/bin/sh";
        openssh.authorizedKeys.keyFiles = [
          ../../../secrets/builder-ssh-key.pub
        ];
      };
      users.groups.remotebuild = { };
    })
  ];
}
