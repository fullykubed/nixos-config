{
  config,
  pkgs,
  lib,
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

  # Script to send an AI-summarized notification for a completed command
  awayNotifyCmd = pkgs.writeShellScriptBin "away-notify-cmd" ''
        # Recursion guard — prevent re-entry if called from within a Claude session
        [[ "''${_AWAY_NOTIFY_ACTIVE:-}" = "1" ]] && exit 0

        # Validate args (fail fast here)
        command="''${1:?Usage: away-notify-cmd <command> <exit_code> [output]}"
        exit_code="''${2:?Usage: away-notify-cmd <command> <exit_code> [output]}"
        output="''${3:-}"

        # Sanitize command text: collapse to single line, cap length
        command=$(${pkgs.coreutils}/bin/printf '%s' "$command" | ${pkgs.coreutils}/bin/tr -d '\000' | ${pkgs.coreutils}/bin/tr '\n' ' ' | ${pkgs.coreutils}/bin/cut -c1-200)

        # From here on, never exit on error — always try to send *something*
        set +e

        # Truncate output to last 3000 characters to stay within reasonable input size
        if [[ -n "$output" ]]; then
          output=$(${pkgs.coreutils}/bin/printf '%s' "$output" | ${pkgs.coreutils}/bin/tr -d '\000' | ${pkgs.coreutils}/bin/tail -c 3000)
        fi

        # Build prompt for Haiku
        prompt="Command: $command
    Exit code: $exit_code"
        [[ -n "$output" ]] && prompt+="
    Output (last lines):
    $output"

        # Re-check away status before making the LLM call (user may have returned)
        ${isAway}/bin/is-away || exit 0

        # Generate summary via Claude Haiku
        summary=$(${pkgs.coreutils}/bin/printf '%s' "$prompt" | _AWAY_NOTIFY_ACTIVE=1 claude-wrapper -p \
          --model haiku \
          --no-session-persistence \
          --tools "" \
          --strict-mcp-config --mcp-config '{"mcpServers":{}}' \
          --append-system-prompt "Summarize this command result in 20 words or less. Start with SUCCESS or FAILURE. Mention the command name. Output only the summary." \
          2>/dev/null) || summary=""

        # Fallback if Haiku failed or returned empty output
        if [[ -z "$summary" ]]; then
          if [[ "$exit_code" = "0" ]]; then
            summary="✓ $command completed successfully"
          else
            summary="✗ $command failed (exit $exit_code)"
          fi
        fi

        # Determine title based on exit code
        if [[ "$exit_code" = "0" ]]; then
          title="Command Succeeded"
        else
          title="Command Failed"
        fi

        ${notifyIfAway}/bin/notify-if-away --force "$title" "$summary"
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
  config = lib.mkIf (config.deviceType != "remote-builder") {
    age.secrets = {
      pushover-token = {
        rekeyFile = ../../../secrets/pushover-token.age;
        owner = config.username;
        group = "users";
        mode = "0400";
      };
    };
  
    environment.systemPackages = [
      isAway
      notifyIfAway
      awayNotifyCmd
    ];
  
    systemd.services.nix-build-failure-notify = {
      description = "Monitor nix builds and notify on failure when user is away";
      wantedBy = [ "multi-user.target" ];
      after = [
        "nix-daemon.service"
        "network-online.target"
        "nss-lookup.target"
      ];
      wants = [
        "network-online.target"
        "nss-lookup.target"
      ];
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
  
    home-manager.users.${config.username} = {
      programs.zsh.initContent = ''
        # Away notification hooks
        autoload -U add-zsh-hook
  
        _away_notify_preexec() {
          _AWAY_NOTIFY_CMD="$1"
        }
  
        _away_notify_precmd() {
          local exit_code=$?
  
          # Skip if no command was run (bare Enter)
          [[ -z "''${_AWAY_NOTIFY_CMD:-}" ]] && return
  
          local cmd="$_AWAY_NOTIFY_CMD"
          _AWAY_NOTIFY_CMD=""
  
          # Only notify if user is away
          ${isAway}/bin/is-away || return
  
          # Capture output if in tmux
          local output=""
          if [[ -n "''${TMUX:-}" ]]; then
            output=$(tmux capture-pane -p -S -50 2>/dev/null | ${pkgs.gnused}/bin/sed -r 's/\x1B\[[0-9;]*[a-zA-Z]//g; s/\x1B\][^\x07]*\x07//g; s/\r//g' || true)
          fi
  
          # Send notification in background
          (${awayNotifyCmd}/bin/away-notify-cmd "$cmd" "$exit_code" "$output" &) 2>/dev/null
        }
  
        add-zsh-hook preexec _away_notify_preexec
        add-zsh-hook precmd _away_notify_precmd
      '';
    };
  };
}
