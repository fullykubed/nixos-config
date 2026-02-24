#!/usr/bin/env bash
# modules/common/binary-cache/upload-daemon.sh
# Oneshot script that processes all pending cache upload queue items.
# Run by a systemd timer. Exits non-zero if any uploads fail.
#
# Queue layout (/var/lib/cache-upload-queue/):
#   pending/  -- one file per store path (filename = hash, content = full path)
#   done/     -- empty marker files for deduplication (pruned periodically)

set -euo pipefail

QUEUE_DIR="/var/lib/cache-upload-queue"
PENDING_DIR="$QUEUE_DIR/pending"
DONE_DIR="$QUEUE_DIR/done"

mkdir -p "$PENDING_DIR" "$DONE_DIR"

log() { echo "[$(date -Iseconds)] $*"; }

# Check cache availability
export NIKS3_SERVER_URL
NIKS3_SERVER_URL=$(cat /run/niks3-server-url 2>/dev/null || echo "")
if [ -z "$NIKS3_SERVER_URL" ]; then
  log "Cache not available (no /run/niks3-server-url), skipping"
  exit 0
fi

export NIKS3_AUTH_TOKEN_FILE="${NIKS3_AUTH_TOKEN_FILE:-/run/agenix/niks3-api-token}"
if [ ! -f "$NIKS3_AUTH_TOKEN_FILE" ]; then
  log "Auth token not available at $NIKS3_AUTH_TOKEN_FILE, skipping"
  exit 0
fi

BATCH_SIZE=32
count=0
failed=0
batch_paths=()
batch_files=()
batch_hashes=()

for pending_file in "$PENDING_DIR"/*; do
  [ -f "$pending_file" ] || continue

  hash=$(basename "$pending_file")

  # Skip if already uploaded (deduplication)
  if [ -f "$DONE_DIR/$hash" ]; then
    rm -f "$pending_file"
    continue
  fi

  store_path=$(cat "$pending_file" 2>/dev/null || echo "")
  if [ -z "$store_path" ]; then
    rm -f "$pending_file"
    continue
  fi

  # Verify the store path still exists
  if [ ! -e "$store_path" ]; then
    log "WARN: Store path gone, skipping: $store_path"
    rm -f "$pending_file"
    continue
  fi

  batch_paths+=("$store_path")
  batch_files+=("$pending_file")
  batch_hashes+=("$hash")

  if [ "${#batch_paths[@]}" -ge "$BATCH_SIZE" ]; then
    # Re-check cache availability before each batch
    if [ ! -f /run/niks3-server-url ]; then
      log "Cache went offline mid-batch, stopping (${count} uploaded, ${failed} failed)"
      exit 1
    fi

    push_err=""
    if push_err=$(niks3 push "${batch_paths[@]}" 2>&1); then
      for i in "${!batch_hashes[@]}"; do
        touch "$DONE_DIR/${batch_hashes[$i]}"
        rm -f "${batch_files[$i]}"
      done
      count=$((count + ${#batch_paths[@]}))
    else
      failed=$((failed + ${#batch_paths[@]}))
      log "FAIL batch (${#batch_paths[@]} paths): $push_err"
    fi

    batch_paths=()
    batch_files=()
    batch_hashes=()
  fi
done

# Upload remaining paths
if [ "${#batch_paths[@]}" -gt 0 ]; then
  if [ ! -f /run/niks3-server-url ]; then
    log "Cache went offline mid-batch, stopping (${count} uploaded, ${failed} failed)"
    exit 1
  fi

  push_err=""
  if push_err=$(niks3 push "${batch_paths[@]}" 2>&1); then
    for i in "${!batch_hashes[@]}"; do
      touch "$DONE_DIR/${batch_hashes[$i]}"
      rm -f "${batch_files[$i]}"
    done
    count=$((count + ${#batch_paths[@]}))
  else
    failed=$((failed + ${#batch_paths[@]}))
    log "FAIL batch (${#batch_paths[@]} paths): $push_err"
  fi
fi

if [ "$count" -gt 0 ] || [ "$failed" -gt 0 ]; then
  log "Batch complete: ${count} uploaded, ${failed} failed"
fi

if [ "$failed" -gt 0 ]; then
  exit 1
fi
