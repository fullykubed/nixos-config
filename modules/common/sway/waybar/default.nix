{
  config,
  pkgs,
  lib,
  ...
}:
let
  waybarBuildersScript = pkgs.writeShellScriptBin "waybar-builders" (
    builtins.readFile ./waybar-builders.sh
  );
  waybarStyle = pkgs.runCommand "waybar-style.css" { } ''
        cat ${pkgs.waybar}/etc/xdg/waybar/style.css > $out
        cat >> $out << 'CUSTOM'

    /* Builder + cache module styles */
    #custom-builders {
        background-color: #a3d9a5;
        color: #2d3436;
        padding: 0 10px;
        border-radius: 4px;
        margin: 2px 0;
    }

    #custom-builders.idle {
        background-color: transparent;
        color: #ffffff;
    }

    #custom-builders.partial {
        background-color: #ffeaa7;
        color: #2d3436;
    }

    #custom-builders.warning {
        background-color: #fdcb6e;
        color: #2d3436;
    }
    CUSTOM
  '';
in
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
        Environment = [
          "PATH=${
            lib.makeBinPath [
              pkgs.waybar
              waybarBuildersScript
              pkgs.jaq
              pkgs.curl
              pkgs.findutils
            ]
          }:/run/current-system/sw/bin"
        ];
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

    xdg.configFile."waybar/style.css" = {
      source = waybarStyle;
      onChange = "${pkgs.systemd}/bin/systemctl --user restart waybar || true";
    };
  };
}
