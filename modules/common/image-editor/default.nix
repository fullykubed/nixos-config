{
  config,
  lib,
  nixpkgs-unstable,
  ...
}:
{
  config = lib.mkIf (config.deviceType != "remote-builder") {
    environment.systemPackages = [
      nixpkgs-unstable.drawio # Diagram and flowchart editor
    ];
    home-manager.users.${config.username} = {
      xdg.desktopEntries = {
        drawio = {
          name = "draw.io";
          comment = "Diagram and flowchart editor";
          exec = "${nixpkgs-unstable.drawio}/bin/drawio --disable-gpu";
          type = "Application";
        };
      };
    };
  };
}
