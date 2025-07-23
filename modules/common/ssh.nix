{ config, ... }:
{
  home-manager.users.jack = {
    services.ssh-agent.enable = true;
  };
}
