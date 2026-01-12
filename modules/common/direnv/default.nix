{
  config,
  pkgs,
  ...
}:
{
  home-manager.users.${config.username} = {
    programs.direnv = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
      config = {
        global = {
          warn_timeout = "30m";
          hide_env_diff = true;
        };
      };
    };
    programs.bash.enable = true;
  };
}
