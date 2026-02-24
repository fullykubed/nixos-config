{ config, ... }:
{
  home-manager.users.${config.username} = {
    services.ssh-agent.enable = true;

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
    };
  };
}
