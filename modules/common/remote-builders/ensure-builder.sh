#!/usr/bin/env bash
# modules/common/remote-builders/ensure-builder.sh
# SSH Match exec script: ensures a builder exists and is reachable before SSH
# connects directly via MagicDNS. Exits 0 when the builder is ready.
#
# For bare-metal builders (type = "bare-metal" in /etc/builder-fleet.json),
# only SSH reachability is checked — no Hetzner API calls are made.
# For cloud builders, the builder is provisioned on-demand if not found.

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

TOKEN_FILE="/run/agenix/hetzner-api-token"
FLEET_CONFIG="/etc/builder-fleet.json"
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
# Determine builder type from fleet config
# ------------------------------------------------------------------------------

BUILDER_TYPE=$(jaq -r ".[\"$TARGET_HOST\"].type // \"cloud\"" "$FLEET_CONFIG" 2>/dev/null || echo "cloud")

# ------------------------------------------------------------------------------
# Bare-metal path: SSH reachability check only (no Hetzner API)
# ------------------------------------------------------------------------------

if [[ "$BUILDER_TYPE" == "bare-metal" ]]; then
  if nc -z -w 5 "$TARGET_HOST" "$TARGET_PORT" 2>/dev/null; then
    exit 0
  else
    error "Bare-metal builder $TARGET_HOST is unreachable on port $TARGET_PORT"
  fi
fi

# ------------------------------------------------------------------------------
# Cloud path: validate Hetzner API token and proceed with provisioning
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

# Fast path (no lock needed): builder is already up
if nc -z -w 2 "$TARGET_HOST" "$TARGET_PORT" 2>/dev/null; then
  exit 0
fi

info "Builder $TARGET_HOST not reachable"

# Serialize provisioning per builder name to prevent concurrent ensure-builder
# instances (triggered by parallel nix-daemon SSH connections) from racing to
# create the same server.
LOCK_DIR="/run/ensure-builder"
mkdir -p "$LOCK_DIR"
LOCK_FILE="$LOCK_DIR/$TARGET_HOST.lock"

exec 9>"$LOCK_FILE"
# Track whether this instance created the server so we can clean up on failure
WE_CREATED=false
cleanup() {
  if [[ "$WE_CREATED" == true ]]; then
    info "Cleaning up: destroying partially-provisioned $TARGET_HOST"
    builders destroy "$TARGET_HOST" >&2 || true
  fi
  rm -f "$LOCK_FILE"
}
trap cleanup EXIT
if ! flock -w "$BUILDER_WAIT_TIMEOUT" 9; then
  error "Timed out waiting for lock on $TARGET_HOST"
fi

# Re-check after acquiring the lock — another instance may have provisioned it
if nc -z -w 2 "$TARGET_HOST" "$TARGET_PORT" 2>/dev/null; then
  exit 0
fi

if ! server_exists; then
  info "Builder $TARGET_HOST does not exist in Hetzner, creating..."
  WE_CREATED=true
  if ! builders create "$TARGET_HOST" >&2; then
    # Another machine may have created it concurrently — check before giving up
    if server_exists; then
      WE_CREATED=false
      info "Builder $TARGET_HOST was created by another machine, waiting for it..."
    else
      error "Failed to create server $TARGET_HOST"
    fi
  else
    info "Server $TARGET_HOST created, waiting for it to become reachable..."
  fi
else
  info "Builder $TARGET_HOST exists in Hetzner but is not reachable yet, waiting..."
fi

wait_for_builder "$TARGET_HOST" "$TARGET_PORT" "$BUILDER_WAIT_TIMEOUT"

# Builder is up — disarm the cleanup trap
WE_CREATED=false
