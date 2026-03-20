#!/usr/bin/env bash
# modules/common/remote-builders/proxy-command.sh
# SSH ProxyCommand that provisions Hetzner builders on-demand and connects over Tailscale

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

TOKEN_FILE="/run/agenix/hetzner-api-token"
PRIVKEY_FILE="/root/.ssh/builder-key"
TAILSCALE_WAIT_TIMEOUT=120

# ------------------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------------------

info()  { echo ":: $*" >&2; }
warn()  { echo ":: Warning: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

# ------------------------------------------------------------------------------
# Arguments from SSH (%h %p)
# ------------------------------------------------------------------------------

if [[ $# -lt 2 ]]; then
  error "Usage: $0 <hostname> <port>"
fi

TARGET_HOST="$1"
TARGET_PORT="$2"

# ------------------------------------------------------------------------------
# Validation
# ------------------------------------------------------------------------------

if [[ ! -f "$TOKEN_FILE" ]]; then
  error "Hetzner API token not found at $TOKEN_FILE"
fi

if [[ ! -f "$PRIVKEY_FILE" ]]; then
  error "SSH private key not found at $PRIVKEY_FILE"
fi

export HCLOUD_TOKEN
HCLOUD_TOKEN=$(cat "$TOKEN_FILE")

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

# Get the builder's Tailscale IP from tailscale status --json by hostname
get_tailscale_ip() {
  local hostname="$1"
  # shellcheck disable=SC2016 # $h is a jaq variable, not a shell variable
  tailscale status --json \
    | jaq -r --arg h "$hostname" \
        '.Peer[] | select(.HostName == $h) | .TailscaleIPs[0] // empty'
}

# Check if a server with the given name exists in Hetzner Cloud
server_exists() {
  local output
  if ! output=$(hcloud server describe "$TARGET_HOST" -o json 2>&1); then
    return 1
  fi
  echo "$output" | jaq -e '.id' > /dev/null 2>&1
}

# Poll tailscale status until the builder hostname appears, with a timeout
wait_for_tailscale() {
  local hostname="$1"
  local max_seconds="$2"
  local max_attempts=$(( max_seconds / 5 ))
  local attempt=0
  local ip

  info "Waiting for $hostname to appear in Tailscale network (max ${max_seconds}s)..."

  while [[ $attempt -lt $max_attempts ]]; do
    (( attempt++ )) || true
    ip=$(get_tailscale_ip "$hostname" 2>/dev/null || true)
    if [[ -n "$ip" ]]; then
      info "$hostname appeared in Tailscale after $(( attempt * 5 ))s (IP: $ip)"
      echo "$ip"
      return 0
    fi
    info "  Attempt $attempt/$max_attempts -- not in Tailscale yet, retrying in 5s..."
    sleep 5
  done

  error "Timeout: $hostname did not appear in Tailscale after ${max_seconds}s"
}

# ------------------------------------------------------------------------------
# Main: Discover or Provision Builder
# ------------------------------------------------------------------------------

TAILSCALE_IP=$(get_tailscale_ip "$TARGET_HOST" 2>/dev/null || true)

if [[ -z "$TAILSCALE_IP" ]]; then
  info "Builder $TARGET_HOST not found in Tailscale network"

  if ! server_exists; then
    info "Builder $TARGET_HOST does not exist in Hetzner, creating..."
    if ! builders create "$TARGET_HOST" >&2; then
      error "Failed to create server $TARGET_HOST"
    fi
    info "Server $TARGET_HOST created, waiting for it to join Tailscale..."
  else
    info "Builder $TARGET_HOST exists in Hetzner but has not joined Tailscale yet, waiting..."
  fi

  TAILSCALE_IP=$(wait_for_tailscale "$TARGET_HOST" "$TAILSCALE_WAIT_TIMEOUT")
else
  info "Builder $TARGET_HOST found in Tailscale at $TAILSCALE_IP"
fi

# ------------------------------------------------------------------------------
# Connect via Tailscale IP
# ------------------------------------------------------------------------------

info "Proxying to $TAILSCALE_IP:$TARGET_PORT..."
exec socat - "TCP:$TAILSCALE_IP:$TARGET_PORT"
