{ config, lib, ... }:
{
  config = lib.mkIf (config.deviceType != "remote-builder") {
    home-manager.users.${config.username} = {
      xdg = {
        enable = true;

        # Set up default directories in $HOME
        userDirs = {
          enable = true;
          createDirectories = true;
          desktop = "$HOME/desktop";
          documents = "$HOME/docs";
          music = "$HOME/media";
          videos = "$HOME/media";
          templates = "$HOME/docs";
          pictures = "$HOME/camera";
          download = "$HOME/downloads";
          publicShare = "$HOME/public";
        };

        # Set the default applications for each mime type
        configFile."mimeapps.list".force = true;
        mimeApps.enable = true;
      };
    };
  };
}
