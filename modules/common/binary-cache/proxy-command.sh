#!/usr/bin/env bash
# modules/common/binary-cache/proxy-command.sh
# SSH ProxyCommand for cache server connections

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

TOKEN_FILE="/run/agenix/hetzner-api-token"
PRIVKEY_FILE="/root/.ssh/cache-key"

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
  if ! hcloud server describe "$TARGET_HOST" -o json &>/dev/null; then
    return 1
  fi
  return 0
}

# Get server public IPv4 address
get_server_ip() {
  hcloud server describe "$TARGET_HOST" -o json | jaq -r '.public_net.ipv4.ip'
}

# Wait for server to be reachable via SSH
wait_for_ssh() {
  local ip="$1"
  local max_attempts=60
  local attempt=0

  while [[ $attempt -lt $max_attempts ]]; do
    if nc -z -w 2 "$ip" "$TARGET_PORT" 2>/dev/null; then
      return 0
    fi
    ((attempt++))
    sleep 1
  done

  return 1
}

# ==============================================================================
# Main Logic
# ==============================================================================

# Check if the cache server exists
if ! server_exists; then
  echo "ERROR: Cache server $TARGET_HOST does not exist" >&2
  echo "Create it with: cache create $TARGET_HOST" >&2
  exit 1
fi

# Get the server IP
SERVER_IP=$(get_server_ip)

if [[ -z "$SERVER_IP" ]]; then
  echo "ERROR: Failed to get IP address for $TARGET_HOST" >&2
  exit 1
fi

# Wait for SSH to be available
if ! wait_for_ssh "$SERVER_IP"; then
  echo "ERROR: Timeout waiting for SSH on $TARGET_HOST ($SERVER_IP)" >&2
  exit 1
fi

# Establish the connection using socat
exec socat - "TCP:$SERVER_IP:$TARGET_PORT"
