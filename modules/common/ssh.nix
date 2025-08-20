{ config, ... }:
{
  home-manager.users.${config.username} = {
    services.ssh-agent.enable = true;
  };
}
