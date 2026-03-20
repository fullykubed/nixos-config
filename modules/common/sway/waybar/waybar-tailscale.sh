#!/usr/bin/env bash
# modules/common/sway/waybar/waybar-tailscale.sh
# Waybar custom module for Tailscale network status

set -euo pipefail

ICON=$'\uf6ff' # nf-md-vpn

# Get tailscale status; handle daemon not running or tailscale not installed
if ! STATUS=$(tailscale status --json 2>/dev/null); then
  jq -cn \
    --arg text "$ICON" \
    --arg tooltip "Tailscale: not running" \
    --arg class "disconnected" \
    '{text: $text, tooltip: $tooltip, class: $class}'
  exit 0
fi

STATE=$(echo "$STATUS" | jq -r '.BackendState')

if [[ "$STATE" != "Running" ]]; then
  jq -cn \
    --arg text "$ICON" \
    --arg tooltip "Tailscale: $STATE" \
    --arg class "disconnected" \
    '{text: $text, tooltip: $tooltip, class: $class}'
  exit 0
fi

# Count peers
ONLINE=$(echo "$STATUS" | jq '[.Peer[] | select(.Online)] | length')
TOTAL=$(echo "$STATUS" | jq '[.Peer[]] | length')

# Own info
SELF_HOST=$(echo "$STATUS" | jq -r '.Self.HostName')
SELF_IP=$(echo "$STATUS" | jq -r '.Self.TailscaleIPs[0]')

# Login server (MagicDNS base domain or control URL)
LOGIN_SERVER=$(echo "$STATUS" | jq -r '.CurrentTailnet.MagicDNSSuffix // "unknown"')

# Build tooltip
PEER_LIST=$(echo "$STATUS" | jq -r '.Peer[] | "  \(if .Online then "●" else "○" end) \(.HostName) \(.TailscaleIPs[0])"')

TOOLTIP="${SELF_HOST} (${SELF_IP})"$'\n'"Login server: ${LOGIN_SERVER}"$'\n\n'"Peers (${ONLINE}/${TOTAL} online):"
if [[ -n "$PEER_LIST" ]]; then
  TOOLTIP+=$'\n'"${PEER_LIST}"
fi

TEXT="$ICON $ONLINE"

if [[ "$ONLINE" -eq 0 ]]; then
  CLASS="degraded"
else
  CLASS="connected"
fi

jq -cn \
  --arg text "$TEXT" \
  --arg tooltip "$TOOLTIP" \
  --arg class "$CLASS" \
  '{text: $text, tooltip: $tooltip, class: $class}'
