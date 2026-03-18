{
  config,
  pkgs,
  ...
}:
let
  pushoverUser = "ubeszsjqr12emacca1wgqgca5g3yau";
  idleThreshold = 300; # 5 minutes
  timestampFile = "/run/last-user-input";

  # Script to detect if the user is away (idle >= threshold)
  isAway = pkgs.writeShellScriptBin "is-away" ''
    set -euo pipefail

    IDLE_THRESHOLD=${toString idleThreshold}
    TIMESTAMP_FILE="${timestampFile}"

    [[ ! -f "$TIMESTAMP_FILE" ]] && exit 1

    last_input=$(${pkgs.coreutils}/bin/stat -c %Y "$TIMESTAMP_FILE")
    now=$(${pkgs.coreutils}/bin/date +%s)
    idle_seconds=$((now - last_input))

    ((idle_seconds >= IDLE_THRESHOLD))
  '';

  # Script to send notification if user is away
  notifyIfAway = pkgs.writeShellScriptBin "notify-if-away" ''
    set -euo pipefail

    send_notification() {
        local title="$1" message="$2" priority="''${3:-0}"

        ${pkgs.curl}/bin/curl -s \
            -F "token=$(cat ${config.age.secrets.pushover-token.path})" \
            -F "user=${pushoverUser}" \
            -F "title=$title" \
            -F "message=$message" \
            -F "priority=$priority" \
            https://api.pushover.net/1/messages.json >/dev/null
    }

    # Parse arguments
    force=false
    priority=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force) force=true; shift ;;
            -p|--priority) priority="$2"; shift 2 ;;
            *) break ;;
        esac
    done

    [[ $# -lt 2 ]] && { echo "Usage: notify-if-away [-f] [-p priority] <title> <message>" >&2; exit 1; }

    title="$1"
    message="$2"

    if $force || ${isAway}/bin/is-away; then
        send_notification "$title" "$message" "$priority"
        echo "Notification sent: $title"
    else
        echo "User present - skipped"
    fi
  '';

  # Script to monitor nix-daemon for build failures
  buildFailureMonitor = pkgs.writeShellScript "nix-build-failure-monitor" ''
    set -euo pipefail

    LAST_NOTIFY=0
    DEBOUNCE_SECONDS=30

    ${pkgs.systemd}/bin/journalctl -f -u nix-daemon --since "now" -o cat | \
    while IFS= read -r line; do
        if [[ "$line" =~ error:\ builder\ for\ \'([^\']+)\'\ failed ]] || \
           [[ "$line" =~ error:\ build\ of\ \'([^\']+)\'\ failed ]]; then

            drv="''${BASH_REMATCH[1]}"
            pkg=$(${pkgs.coreutils}/bin/basename "$drv" .drv | ${pkgs.gnused}/bin/sed 's/^[a-z0-9]*-//')

            now=$(${pkgs.coreutils}/bin/date +%s)
            if ((now - LAST_NOTIFY >= DEBOUNCE_SECONDS)); then
                ${notifyIfAway}/bin/notify-if-away -p 1 "Build Failed" "$pkg"
                LAST_NOTIFY=$now
            fi
        fi
    done
  '';

  inputTrackerScript = pkgs.writeShellScript "input-activity-tracker" ''
    ${pkgs.coreutils}/bin/touch "${timestampFile}"
    ${pkgs.coreutils}/bin/chmod 644 "${timestampFile}"
    exec ${pkgs.libinput}/bin/libinput debug-events 2>/dev/null | \
      while IFS= read -r _; do
        ${pkgs.coreutils}/bin/touch "${timestampFile}"
      done
  '';
in
{
  environment.systemPackages = [
    isAway
    notifyIfAway
  ];

  systemd.services.nix-build-failure-notify = {
    description = "Monitor nix builds and notify on failure when user is away";
    wantedBy = [ "multi-user.target" ];
    after = [ "nix-daemon.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${buildFailureMonitor}";
      Restart = "always";
      RestartSec = 5;
    };
  };

  systemd.services.input-activity-tracker = {
    description = "Track user input activity for away detection";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${inputTrackerScript}";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
