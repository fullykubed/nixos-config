{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf (config.deviceType != "remote-builder") {
    environment.systemPackages = with pkgs; [
      swayimg
    ];
    home-manager.users.${config.username} = {

      # Set up desktop applications
      xdg.desktopEntries = {
        "swayimg" = {
          name = "Image Viewer";
          comment = "Image viewer for Sway";
          exec = "swayimg %U";
          type = "Application";
          mimeType = [
            "image/bmp"
            "image/gif"
            "image/png"
            "image/webp"
            "image/jpeg"
          ];
        };
      };
    };
  };
}
