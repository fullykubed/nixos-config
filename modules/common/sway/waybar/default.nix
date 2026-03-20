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
  cloudStatusScript = pkgs.writeShellApplication {
    name = "cloud-status";
    runtimeInputs = [
      pkgs.curl
      pkgs.jaq
      pkgs.coreutils
      pkgs.systemd
      pkgs.util-linux # for mountpoint
    ];
    text = builtins.readFile ./cloud-status.sh;
  };
  waybarSecurebootScript = pkgs.writeShellApplication {
    name = "waybar-secureboot-status";
    runtimeInputs = [
      pkgs.sbctl
      pkgs.jaq
    ];
    text = builtins.readFile ./waybar-secureboot-status.sh;
  };
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

    /* Secure Boot module styles */
    #custom-secureboot {
        padding: 0 10px;
        border-radius: 4px;
        margin: 2px 0;
    }

    #custom-secureboot.ok {
        background-color: transparent;
        color: #ffffff;
    }

    #custom-secureboot.warning {
        background-color: #fdcb6e;
        color: #2d3436;
    }

    #custom-secureboot.error {
        background-color: #ff7675;
        color: #2d3436;
    }

    #custom-secureboot.setup {
        background-color: #ffeaa7;
        color: #2d3436;
    }

    /* Battery module styles */
    #battery {
        padding: 0 10px;
    }

    #battery.charging {
        background-color: #a3d9a5;
        color: #2d3436;
        border-radius: 4px;
        margin: 2px 0;
    }

    #battery.warning:not(.charging) {
        background-color: #ffeaa7;
        color: #2d3436;
        border-radius: 4px;
        margin: 2px 0;
    }

    #battery.critical:not(.charging) {
        background-color: #ff7675;
        color: #2d3436;
        border-radius: 4px;
        margin: 2px 0;
    }
    CUSTOM
  '';
  waybarTailscaleScript = pkgs.writeShellScriptBin "waybar-tailscale" (
    builtins.readFile ./waybar-tailscale.sh
  );
in
{
  age.secrets.cloudflare-api-token = {
    rekeyFile = ../../../../secrets/cloudflare-api-token.age;
    path = "/run/agenix/cloudflare-api-token";
    mode = "0400";
    owner = "root";
  };

  systemd.services.cloud-status = {
    description = "Collect R2 bucket sizes and ccache health for waybar";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RuntimeDirectory = "cloud-status";
      RuntimeDirectoryPreserve = "yes";
    };
    path = [ cloudStatusScript ];
    script = ''
      export CF_API_TOKEN
      CF_API_TOKEN=$(cat ${config.age.secrets.cloudflare-api-token.path})
      cloud-status
    '';
  };

  systemd.timers.cloud-status = {
    description = "Poll R2 bucket sizes and ccache health every 5 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "5min";
    };
  };

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
              waybarSecurebootScript
              waybarTailscaleScript
              pkgs.tailscale
              pkgs.jaq
              pkgs.curl
              pkgs.bfs
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
