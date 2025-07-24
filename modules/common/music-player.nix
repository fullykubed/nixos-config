{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    spotify # Music streaming service
  ];
  home-manager.users.${config.username} = {
    xdg.desktopEntries = {
      spotify = {
        name = "Spotify";
        genericName = "Music streaming service";
        exec = "${pkgs.spotify}/bin/spotify";
        type = "Application";
      };
    };
  };
}