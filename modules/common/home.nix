{ config, ... }:
{

  home.stateVersion = "22.11";

  #################################################
  # Set up default directories in $HOME
  #################################################
  xdg.userDirs = {
    enable = true;
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
    defaultApplications = {
      "x-scheme-handler/http" = [ "firefox.desktop" ];
      "x-scheme-handler/https" = [ "firefox.desktop" ];
      "x-scheme-handler/chrome" = [ "firefox.desktop" ];
      "text/html" = [ "firefox.desktop" ];
      "application/x-extension-htm" = [ "firefox.desktop" ];
      "application/x-extension-html" = [ "firefox.desktop" ];
      "application/x-extension-shtml" = [ "firefox.desktop" ];
      "application/xhtml+xml" = [ "firefox.desktop" ];
      "application/x-extension-xhtml" = [ "firefox.desktop" ];
      "application/x-extension-xht" = [ "firefox.desktop" ];
      "image/jpeg" = [ "swayimg.desktop" ];
      "image/png" = [ "swayimg.desktop" ];
      "image/webp" = [ "swayimg.desktop" ];
      "image/gif" = [ "swayimg.desktop" ];
      "image/bmp" = [ "swayimg.desktop" ];
      "application/pdf" = [ "okular.desktop" ];
      "video/mp4" = [ "mpv.desktop" ];
      "video/webm" = [ "mpv.desktop" ];
      "video/x-m4v" = [ "mpv.desktop" ];
      "video/quicktime" = [ "mpv.desktop" ];
    };
  };
}
