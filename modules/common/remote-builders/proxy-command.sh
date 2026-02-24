#!/usr/bin/env bash
# modules/common/remote-builders/proxy-command.sh
# SSH ProxyCommand that provisions Hetzner builders on-demand

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

TOKEN_FILE="/run/agenix/hetzner-api-token"
PRIVKEY_FILE="/root/.ssh/builder-key"

# ==============================================================================
# Arguments from SSH (%h %p)
# ==============================================================================

if [[ $# -lt 2 ]]; then
  echo "ERROR: Usage: $0 <hostname> <port>" >&2
  exit 1
fi

TARGET_HOST="$1"
TARGET_PORT="$2"

# ==============================================================================
# Validation
# ==============================================================================

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "ERROR: Hetzner API token not found at $TOKEN_FILE" >&2
  exit 1
fi

if [[ ! -f "$PRIVKEY_FILE" ]]; then
  echo "ERROR: SSH private key not found at $PRIVKEY_FILE" >&2
  exit 1
fi

export HCLOUD_TOKEN
HCLOUD_TOKEN=$(cat "$TOKEN_FILE")

# ==============================================================================
# Helper Functions
# ==============================================================================

# Check if a server with the given name exists
server_exists() {
  local output
  if ! output=$(hcloud server describe "$TARGET_HOST" -o json 2>&1); then
    # Server doesn't exist or API error
    return 1
  fi
  echo "$output" | jq -e '.id' > /dev/null 2>&1
}

# Get the public IPv4 address of the server
get_server_ip() {
  local output
  if ! output=$(hcloud server describe "$TARGET_HOST" -o json 2>&1); then
    echo "ERROR: Failed to get server info: $output" >&2
    exit 1
  fi
  echo "$output" | jq -r '.public_net.ipv4.ip'
}

# Wait until SSH port is reachable on the given IP
wait_for_ssh() {
  local ip="$1"
  local max_seconds="$2"
  local max_attempts=$((max_seconds / 2))
  local attempt=0

  echo "Waiting for SSH port on $ip:3098 (max ${max_seconds}s)..." >&2

  while [[ $attempt -lt $max_attempts ]]; do
    ((attempt++))
    if nc -z -w 2 "$ip" 3098 2>/dev/null; then
      echo "SSH port ready after $((attempt * 2)) seconds" >&2
      return 0
    fi
    echo "  Attempt $attempt/$max_attempts - not ready, retrying..." >&2
    sleep 2
  done

  echo "SSH port not ready after $max_seconds seconds" >&2
  return 1
}

# ==============================================================================
# Provision Server if Needed
# ==============================================================================

JUST_CREATED=false

if ! server_exists; then
  echo "Builder $TARGET_HOST does not exist, creating..." >&2

  # Use the builders CLI to create the server with proper user-data
  if ! builders create "$TARGET_HOST" >&2; then
    echo "ERROR: Failed to create server $TARGET_HOST" >&2
    exit 1
  fi

  JUST_CREATED=true
  echo "Server $TARGET_HOST created, waiting for SSH..." >&2
else
  echo "Builder $TARGET_HOST already exists, connecting..." >&2
fi

# ==============================================================================
# Connect
# ==============================================================================

IP=$(get_server_ip)

if [[ -z "$IP" ]] || [[ "$IP" == "null" ]]; then
  echo "ERROR: Could not determine IP address for $TARGET_HOST" >&2
  exit 1
fi

echo "Server IP: $IP" >&2

# Wait longer for newly created servers (60s) vs existing ones (20s)
if [[ "$JUST_CREATED" == true ]]; then
  SSH_TIMEOUT=60
else
  SSH_TIMEOUT=20
fi

if ! wait_for_ssh "$IP" "$SSH_TIMEOUT"; then
  echo "ERROR: Timeout waiting for SSH port on $IP" >&2
  exit 1
fi

echo "Proxying to $IP:$TARGET_PORT..." >&2

# Proxy the TCP connection via socat
exec socat - "TCP:$IP:$TARGET_PORT"
