{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf (config.deviceType != "remote-builder") {
    environment.systemPackages = with pkgs; [
      qbittorrent # Bittorrent client
    ];
    home-manager.users.${config.username} = {
      xdg.desktopEntries = {
        qbittorrent = {
          name = "qBittorrent";
          comment = "Download and share files over BitTorrent";
          exec = "${pkgs.qbittorrent}/bin/qbittorrent";
          type = "Application";
        };
      };
    };
  };
}
