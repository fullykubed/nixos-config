{ config, ... }:
{

  home-manager.users.${config.username} = {
    xdg.enable = true;

    # Set up default directories in $HOME
    xdg.userDirs = {
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
    xdg.configFile."mimeapps.list".force = true;
    xdg.mimeApps = {
      enable = true;
    };
  };
}
