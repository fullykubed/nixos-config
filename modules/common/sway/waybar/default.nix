{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Read the idle-timeout constant from the shared builder config so it stays
  # in sync with images/builder/inactivity-monitor.nix without hard-coding.
  builderConfig = import ../../../../lib/builder-config.nix;
  waybarBuildersSrc =
    builtins.replaceStrings [ "@idle_timeout@" ] [ (toString builderConfig.inactivityTimeoutMinutes) ]
      (builtins.readFile ./waybar-builders.sh);
  waybarBuildersScript = pkgs.writeShellApplication {
    name = "waybar-builders";
    runtimeInputs = [
      pkgs.jaq
      pkgs.coreutils
      pkgs.bfs
      pkgs.curl
      pkgs.systemd
    ];
    text = waybarBuildersSrc;
  };
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

  isLaptop = config.deviceType == "laptop";

  waybarConfigAttrs = {
    height = 30;
    spacing = 4;
    "modules-left" = [
      "sway/workspaces"
      "sway/mode"
      "sway/scratchpad"
    ];
    "modules-center" = [ "sway/window" ];
    "modules-right" = [
      "custom/secureboot"
      "custom/systemd-failed"
      "custom/builders"
      "custom/controller"
      "custom/ai-spend"
      "custom/tailscale"
      "custom/voxtype"
      "idle_inhibitor"
      "pulseaudio"
      "network"
      "cpu"
      "memory"
      "temperature"
    ]
    ++ lib.optionals isLaptop [ "battery" ]
    ++ [
      "clock"
      "custom/notification"
      "tray"
    ];
    "keyboard-state" = {
      numlock = true;
      capslock = true;
      format = "{name} {icon}";
      "format-icons" = {
        locked = "";
        unlocked = "";
      };
    };
    "sway/mode" = {
      format = ''<span style="italic">{}</span>'';
    };
    "sway/scratchpad" = {
      format = "{icon} {count}";
      "show-empty" = false;
      "format-icons" = [
        ""
        ""
      ];
      tooltip = true;
      "tooltip-format" = "{app}: {title}";
    };
    idle_inhibitor = {
      format = "{icon}";
      "format-icons" = {
        activated = "";
        deactivated = "";
      };
    };
    tray = {
      spacing = 10;
    };
    clock = {
      timezone = "America/Indiana/Indianapolis";
      format = "{:%I:%M %p}";
      "format-alt" = "{:%Y-%m-%d %I:%M %p}";
      "tooltip-format" = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      locale = "C";
    };
    cpu = {
      format = "{usage}% ";
      tooltip = false;
    };
    memory = {
      format = "{}% ";
    };
    temperature = {
      "critical-threshold" = 80;
      format = "{temperatureC}°C {icon}";
      "format-icons" = [
        ""
        ""
        ""
      ];
    };
    backlight = {
      format = "{percent}% {icon}";
      "format-icons" = [
        ""
        ""
        ""
        ""
        ""
        ""
        ""
        ""
        ""
      ];
    };
    network = {
      "format-wifi" = "{essid} ({signalStrength}%) ";
      "format-ethernet" = "{ipaddr}/{cidr} ";
      "tooltip-format" = "{ifname} via {gwaddr} ";
      "format-linked" = "{ifname} (No IP) ";
      "format-disconnected" = "Disconnected ⚠";
      "format-alt" = "{ifname}: {ipaddr}/{cidr}";
    };
    pulseaudio = {
      format = "{volume}% {icon} {format_source}";
      "format-bluetooth" = "{volume}% {icon} {format_source}";
      "format-bluetooth-muted" = " {icon} {format_source}";
      "format-muted" = " {format_source}";
      "format-source" = "{volume}% ";
      "format-source-muted" = "";
      "format-icons" = {
        headphone = "";
        "hands-free" = "";
        headset = "";
        phone = "";
        portable = "";
        car = "";
        default = [
          ""
          ""
          ""
        ];
      };
      "on-click" = "pavucontrol";
    };
    "custom/notification" = {
      tooltip = false;
      format = "{icon}";
      "format-icons" = {
        notification = "<span foreground='red'><sup></sup></span>";
        none = "";
        "dnd-notification" = "<span foreground='red'><sup></sup></span>";
        "dnd-none" = "";
        "inhibited-notification" = "<span foreground='red'><sup></sup></span>";
        "inhibited-none" = "";
        "dnd-inhibited-notification" = "<span foreground='red'><sup></sup></span>";
        "dnd-inhibited-none" = "";
      };
      "return-type" = "json";
      "exec-if" = "which swaync-client";
      exec = "swaync-client -swb";
      "on-click" = "swaync-client -t -sw";
      "on-click-right" = "swaync-client -d -sw";
      escape = true;
    };
    "custom/voxtype" = {
      exec = "voxtype status --follow --format json";
      "return-type" = "json";
      format = "{}";
      tooltip = true;
    };
    "custom/secureboot" = {
      exec = "waybar-secureboot-status";
      "exec-if" = "which waybar-secureboot-status";
      "return-type" = "json";
      format = "{}";
      interval = 300;
      tooltip = true;
    };
    "custom/systemd-failed" = {
      exec = "waybar-systemd-failed";
      "exec-if" = "which waybar-systemd-failed";
      "return-type" = "json";
      format = "{}";
      escape = true;
      interval = 30;
      "on-click" =
        "swaymsg exec 'wezterm start --always-new-process --class systemd-manager -- doas systemd-manager-tui'";
    };
    "custom/builders" = {
      exec = "waybar-builders";
      "return-type" = "json";
      format = "{}";
      interval = 60;
      tooltip = true;
    };
    "custom/controller" = {
      exec = "waybar-controller";
      "return-type" = "json";
      format = "{}";
      interval = 60;
      tooltip = true;
      "on-click" = "swaymsg exec 'wezterm start --always-new-process -- doas controller check'";
    };
    "custom/ai-spend" = {
      exec = "waybar-ai-spend";
      "exec-if" = "which waybar-ai-spend";
      "return-type" = "json";
      format = "{}";
      interval = 60;
      tooltip = true;
    };
    "custom/tailscale" = {
      exec = "waybar-tailscale";
      "return-type" = "json";
      format = "{}";
      interval = 30;
      tooltip = true;
    };
  }
  // lib.optionalAttrs isLaptop {
    battery = {
      interval = 30;
      states = {
        good = 80;
        warning = 20;
        critical = 10;
      };
      format = "{capacity}% {icon}";
      "format-charging" = "{capacity}% 󰂄";
      "format-plugged" = "{capacity}% 󰚥";
      "format-full" = "Full 󰁹";
      "format-time" = "{H}h {M}min";
      "format-icons" = [
        "󰂎"
        "󰁺"
        "󰁻"
        "󰁼"
        "󰁽"
        "󰁾"
        "󰁿"
        "󰂀"
        "󰂁"
        "󰂂"
        "󰁹"
      ];
      tooltip = true;
      "tooltip-format" = "{capacity}% — {timeTo}\n{power:.1f}W";
    };
  };

  waybarConfig = pkgs.writeText "waybar-config" (builtins.toJSON waybarConfigAttrs);
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
      restartIfChanged = false;
      reloadIfChanged = true;
      after = [
        "network-online.target"
        "nss-lookup.target"
      ];
      wants = [
        "network-online.target"
        "nss-lookup.target"
      ];
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
      restartIfChanged = false;
      reloadIfChanged = true;
      after = [
        "network-online.target"
        "nss-lookup.target"
      ];
      wants = [
        "network-online.target"
        "nss-lookup.target"
      ];
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
          # Skip (not fail) if no Claude usage data exists yet.
          # ccusage exits 1 when ~/.claude/projects or ~/.config/claude/projects
          # is absent. ExecCondition exit 1-254 → service inactive, not failed.
          ExecCondition = "${pkgs.bash}/bin/bash -c 'test -d %h/.claude/projects || test -d %h/.config/claude/projects'";
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
      source = waybarConfig;
      onChange = "${pkgs.systemd}/bin/systemctl --user restart waybar || true";
    };

    xdg.configFile."waybar/style.css" = {
      source = waybarStyle;
      onChange = "${pkgs.systemd}/bin/systemctl --user restart waybar || true";
    };
  };
}
