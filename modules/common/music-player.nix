{ config, pkgs, ... }:
let
  # Create an FHS environment for Spotify to bypass system allocator
  spotify-fhs = pkgs.buildFHSEnv {
    name = "spotify";
    targetPkgs = pkgs: [ pkgs.unstable.spotify ];
    runScript = "spotify";
  };
in
{
  environment.systemPackages = with pkgs; [
    spotify-fhs # Music streaming service in isolated FHS environment
  ];
  home-manager.users.${config.username} = {
    xdg.desktopEntries = {
      spotify = {
        name = "Spotify";
        genericName = "Music streaming service";
        exec = "${spotify-fhs}/bin/spotify";
        type = "Application";
      };
    };
  };
}
