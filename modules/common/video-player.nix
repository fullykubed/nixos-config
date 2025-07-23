{ config, pkgs, ... }:
let

  mimetypes = [
    "video/mp4"
    "video/webm"
    "video/x-m4v"
    "video/quicktime"
    "video/mpeg"
    "video/x-matroska"
    "video/h264"
    "video/ogg"
  ];
in
{
  environment.systemPackages = with pkgs; [
    mpv # Wayland-native video player
    vlc # Fallback media player
  ];

  home-manager.users.${config.username} = {

    xdg.mimeApps = {
      defaultApplications = builtins.listToAttrs (
        map (mime: {
          name = mime;
          value = [
            "mpv.desktop"
            "vlc.desktop"
          ];
        }) mimetypes
      );
    };

    # Set up desktop applications
    xdg.desktopEntries = {
      mpv = {
        name = "Video Player";
        comment = "mpv Video player (Wayland native)";
        exec = "${pkgs.mpv}/bin/mpv %U";
        type = "Application";
        mimeType = mimetypes;
      };
      vlc = {
        name = "VLC";
        comment = "Video player (fallback)";
        exec = "${pkgs.vlc}/bin/vlc %U";
        type = "Application";
        mimeType = mimetypes;
      };
    };
  };
}
