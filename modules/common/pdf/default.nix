{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf (config.deviceType != "remote-builder") {
    home-manager.users.${config.username} = {
      xdg = {
        mimeApps = {
          enable = true;
          defaultApplications = {
            "application/pdf" = [ "okular.desktop" ];
          };
        };
        desktopEntries = {
          okular = {
            name = "okular";
            comment = "PDF viewer and editor";
            exec = "okular";
            type = "Application";
          };
        };
      };
    };

    environment.systemPackages = with pkgs; [
      kdePackages.okular # PDF editing
    ];
  };
}
