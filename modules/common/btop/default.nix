{
  config,
  ...
}:
{
  home-manager.users.${config.username} = {
    programs.btop = {
      enable = true;
    };
  };
}
