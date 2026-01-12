{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    unstable.drawio # Diagram and flowchart editor
  ];
  home-manager.users.${config.username} = {
    xdg.desktopEntries = {
      drawio = {
        name = "draw.io";
        comment = "Diagram and flowchart editor";
        exec = "${pkgs.unstable.drawio}/bin/drawio --disable-gpu";
        type = "Application";
      };
    };
  };
}
