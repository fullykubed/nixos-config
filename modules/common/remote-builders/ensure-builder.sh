#!/usr/bin/env bash
# modules/common/remote-builders/ensure-builder.sh
# SSH Match exec script: ensures a builder exists and is reachable before SSH
# connects directly via MagicDNS. Exits 0 when the builder is ready.

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

TOKEN_FILE="/run/agenix/hetzner-api-token"
BUILDER_WAIT_TIMEOUT=900

# ------------------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------------------

info()  { echo ":: $*" >&2; }
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

export HCLOUD_TOKEN
HCLOUD_TOKEN=$(cat "$TOKEN_FILE")

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

# Check if a server with the given name exists in Hetzner Cloud
server_exists() {
  local output
  if ! output=$(hcloud server describe "$TARGET_HOST" -o json 2>&1); then
    return 1
  fi
  echo "$output" | jaq -e '.id' > /dev/null 2>&1
}

# Wait for builder to be reachable on its SSH port via MagicDNS
wait_for_builder() {
  local hostname="$1"
  local port="$2"
  local max_seconds="$3"
  local max_attempts=$(( max_seconds / 5 ))
  local attempt=0

  info "Waiting for $hostname:$port to be reachable (max ${max_seconds}s)..."

  while [[ $attempt -lt $max_attempts ]]; do
    (( attempt++ )) || true
    if nc -z -w 2 "$hostname" "$port" 2>/dev/null; then
      info "$hostname:$port reachable after $(( attempt * 5 ))s"
      return 0
    fi
    info "  Attempt $attempt/$max_attempts -- not reachable yet, retrying in 5s..."
    sleep 5
  done

  error "Timeout: $hostname:$port not reachable after ${max_seconds}s"
}

# ------------------------------------------------------------------------------
# Main: Ensure builder is provisioned and reachable
# ------------------------------------------------------------------------------

if nc -z -w 2 "$TARGET_HOST" "$TARGET_PORT" 2>/dev/null; then
  exit 0
fi

info "Builder $TARGET_HOST not reachable"

if ! server_exists; then
  info "Builder $TARGET_HOST does not exist in Hetzner, creating..."
  if ! builders create "$TARGET_HOST" >&2; then
    error "Failed to create server $TARGET_HOST"
  fi
  info "Server $TARGET_HOST created, waiting for it to become reachable..."
else
  info "Builder $TARGET_HOST exists in Hetzner but is not reachable yet, waiting..."
fi

wait_for_builder "$TARGET_HOST" "$TARGET_PORT" "$BUILDER_WAIT_TIMEOUT"
