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
  waybarControllerScript = pkgs.writeShellApplication {
    name = "waybar-controller";
    runtimeInputs = [
      pkgs.jaq
      pkgs.coreutils
    ];
    text = builtins.readFile ./waybar-controller.sh;
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

    /* Controller health module styles */
    #custom-controller {
        padding: 0 10px;
        border-radius: 4px;
        margin: 2px 0;
    }

    #custom-controller.healthy {
        background-color: #a3d9a5;
        color: #2d3436;
    }

    #custom-controller.degraded {
        background-color: #ffeaa7;
        color: #2d3436;
    }

    #custom-controller.offline {
        background-color: #ff7675;
        color: #2d3436;
    }

    /* Tailscale module styles */
    #custom-tailscale {
        padding: 0 10px;
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

    /* AI spend module styles */
    #custom-ai-spend {
        padding: 0 10px;
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
  aiSpendStatusScript = pkgs.writeShellApplication {
    name = "ai-spend-status";
    runtimeInputs = [
      pkgs.curl
      pkgs.jaq
      pkgs.coreutils
    ];
    text = builtins.readFile ./ai-spend-status.sh;
  };
  waybarAiSpendScript = pkgs.writeShellApplication {
    name = "waybar-ai-spend";
    runtimeInputs = [
      pkgs.jaq
      pkgs.coreutils
    ];
    text = builtins.readFile ./waybar-ai-spend.sh;
  };
  ccusage = pkgs.stdenv.mkDerivation {
    pname = "ccusage";
    version = config.versions.ccusage;

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/ccusage/-/ccusage-${config.versions.ccusage}.tgz";
      hash = config.versions.ccusageSrcHash;
    };

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/node_modules/ccusage
      cp -r ./* $out/lib/node_modules/ccusage/

      mkdir -p $out/bin
      makeWrapper ${pkgs.nodejs_20}/bin/node $out/bin/ccusage \
        --add-flags "$out/lib/node_modules/ccusage/dist/index.js"

      runHook postInstall
    '';
  };

  ccusageCacheScript = pkgs.writeShellApplication {
    name = "ccusage-cache";
    runtimeInputs = [
      ccusage
      pkgs.jaq
      pkgs.coreutils
    ];
    text = builtins.readFile ./ccusage-cache.sh;
  };
in
{
  age.secrets.cloudflare-api-token = {
    rekeyFile = ../../../../secrets/cloudflare-api-token.age;
    path = "/run/agenix/cloudflare-api-token";
    mode = "0400";
    owner = "root";
  };

  age.secrets.exa-service-key = {
    rekeyFile = ../../../../secrets/exa-service-key.age;
    mode = "0400";
    owner = "root";
  };

  systemd = {
    services.cloud-status = {
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

    timers.cloud-status = {
      description = "Poll R2 bucket sizes and ccache health every 5 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "5min";
      };
    };

    services.ai-spend-status = {
      description = "Collect AI service spend data for waybar";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RuntimeDirectory = "ai-spend-status";
        RuntimeDirectoryPreserve = "yes";
        StateDirectory = "ai-spend-status";
      };
      path = [ aiSpendStatusScript ];
      script = ''
        export EXA_API_TOKEN
        EXA_API_TOKEN=$(cat ${config.age.secrets.exa-service-key.path})
        ai-spend-status
      '';
    };

    timers.ai-spend-status = {
      description = "Poll AI service spend data every 5 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "5min";
      };
    };
  };

  home-manager.users.${config.username} = {
    # Waybar status bar + ccusage cache systemd units
    systemd.user = {
      services.waybar = {
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
                waybarControllerScript
                waybarSecurebootScript
                waybarTailscaleScript
                waybarAiSpendScript
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

      services.ccusage-cache = {
        Unit = {
          Description = "Cache ccusage token stats for waybar";
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${ccusageCacheScript}/bin/ccusage-cache";
        };
      };

      timers.ccusage-cache = {
        Unit = {
          Description = "Refresh ccusage token cache every 5 minutes";
        };
        Timer = {
          OnBootSec = "1min";
          OnUnitActiveSec = "5min";
        };
        Install = {
          WantedBy = [ "timers.target" ];
        };
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
