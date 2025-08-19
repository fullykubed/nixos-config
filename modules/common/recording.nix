{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    obs-studio # Recording + streaming
    scarlett2 # Firmware management for recording devices
    alsa-scarlett-gui # GUI for scarlett mixer
  ];
  home-manager.users.${config.username} = {
    xdg.desktopEntries = {
      obs-studio = {
        name = "OBS Studio";
        comment = "Free and open source streaming/recording program";
        exec = "${pkgs.obs-studio}/bin/obs";
        type = "Application";
      };
    };
  };
}
