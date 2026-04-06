{ pkgs, ... }:
let
  inherit (import ../../lib/builder-config.nix) inactivityTimeoutMinutes;

  inactivityScript = pkgs.writeShellScript "inactivity-monitor" ''
    set -euo pipefail

    IDLE_FILE="/var/lib/inactivity-monitor/idle-count"
    TIMEOUT_CHECKS=${toString inactivityTimeoutMinutes}  # checks at 1-minute intervals
    TOKEN_FILE="/run/hcloud-token"
    METADATA_URL="http://169.254.169.254/hetzner/v1/metadata/instance-id"

    # Check for activity
    is_active() {
      # Check for nixbld processes (active builds)
      # Each concurrent build runs as a unique nixbld user (nixbld1..N)
      if ${pkgs.procps}/bin/ps -eo user= 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '^nixbld'; then
        echo "Activity detected: nixbld processes running"
        return 0
      fi

      return 1
    }

    if is_active; then
      echo "Activity detected, resetting idle counter"
      echo "0" > "$IDLE_FILE"
      exit 0
    fi

    # Increment idle counter
    IDLE_COUNT=$(cat "$IDLE_FILE" 2>/dev/null || echo "0")
    IDLE_COUNT=$((IDLE_COUNT + 1))
    echo "$IDLE_COUNT" > "$IDLE_FILE"

    echo "Idle check $IDLE_COUNT of $TIMEOUT_CHECKS"

    if [ "$IDLE_COUNT" -ge "$TIMEOUT_CHECKS" ]; then
      echo "Inactivity timeout reached, initiating self-destruction"

      if [ ! -f "$TOKEN_FILE" ]; then
        echo "ERROR: Token file not found at $TOKEN_FILE"
        exit 1
      fi

      SERVER_ID=$(${pkgs.curl}/bin/curl -sf "$METADATA_URL")
      if [ -z "$SERVER_ID" ]; then
        echo "ERROR: Failed to retrieve server ID from Hetzner metadata API"
        exit 1
      fi

      export HCLOUD_TOKEN
      HCLOUD_TOKEN=$(cat "$TOKEN_FILE")
      if [ -z "$HCLOUD_TOKEN" ]; then
        echo "ERROR: Token file at $TOKEN_FILE is empty"
        exit 1
      fi

      # Read builder name for ccache volume detachment
      BUILDER_NAME=""
      if [ -f "/run/builder-name" ]; then
        BUILDER_NAME=$(cat /run/builder-name)
      fi

      # Unmount and detach ccache volume before server deletion
      if ${pkgs.util-linux}/bin/mountpoint -q /var/cache/ccache; then
        echo "Unmounting /var/cache/ccache..."
        sync
        umount /var/cache/ccache || echo "WARNING: Failed to unmount /var/cache/ccache"
      fi
      if [ -n "$BUILDER_NAME" ]; then
        echo "Detaching ccache volume ccache-$BUILDER_NAME..."
        ${pkgs.hcloud}/bin/hcloud volume detach "ccache-$BUILDER_NAME" || \
          echo "WARNING: Failed to detach ccache volume (may not exist or already detached)"
      fi


      # Deregister from headscale before deleting — hcloud server delete
      # hard-kills the VM so ExecStop hooks never fire.
      echo "Logging out of tailscale..."
      ${pkgs.tailscale}/bin/tailscale logout || true

      echo "Deleting server $SERVER_ID..."
      ${pkgs.hcloud}/bin/hcloud server delete "$SERVER_ID" \
        || echo "ERROR: hcloud server delete failed with exit code $?"
    fi
  '';
in
{
  systemd.services.inactivity-monitor = {
    description = "Monitor for build inactivity and self-destruct";
    after = [
      "network.target"
      "builder-tailscale-join.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      StandardOutput = "journal";
      StandardError = "journal";
      ExecStart = inactivityScript;
      # systemd creates /var/lib/inactivity-monitor before ExecStart
      StateDirectory = "inactivity-monitor";
      # Hardening — needs /proc (pgrep) and network (metadata API)
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/inactivity-monitor" ];
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
        "@network-io"
      ];
      SystemCallArchitectures = "native";
    };
  };

  systemd.timers.inactivity-monitor = {
    description = "Run inactivity monitor every minute";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min"; # Wait 5 min after boot before first check
      OnUnitActiveSec = "1min";
      Unit = "inactivity-monitor.service";
    };
  };
}
