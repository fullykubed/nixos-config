{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.deviceType != "remote-builder") {
    home-manager.users.${config.username} = {
      programs.btop = {
        enable = true;
        settings = {
          proc_tree = true;
        };
      };

      programs.zsh.shellAliases = {
        bn = "btop -f nixbld";
      };
    };
  };
}
