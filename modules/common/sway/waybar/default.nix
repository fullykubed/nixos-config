{
  config,
  pkgs,
  lib,
  ...
}:
{
  home-manager.users.${config.username} = {
    # Waybar status bar systemd service
    systemd.user.services.waybar = {
      Unit = {
        Description = "Highly customizable Wayland bar for Sway";
        Documentation = "https://github.com/Alexays/Waybar/wiki";
        PartOf = [ "sway-session.target" ];
        After = [ "sway-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.waybar}/bin/waybar";
        Environment = [ "PATH=${lib.makeBinPath [ pkgs.waybar ]}/bin:/run/current-system/sw/bin" ];
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install = {
        WantedBy = [ "sway-session.target" ];
      };
    };

    xdg.configFile."waybar/config" = {
      source = ./config.json;
      onChange = "${pkgs.systemd}/bin/systemctl --user restart waybar || true";
    };
  };
}
