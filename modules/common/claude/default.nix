{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    unstable.claude-code
  ];

  home-manager.users.${config.username} = {
    home.file.".claude/settings.json" = {
      enable = true;
      source = ./settings.json;
    };
  };
}
