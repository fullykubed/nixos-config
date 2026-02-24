#!/usr/bin/env bash
# modules/common/sway/waybar/waybar-builders.sh
# Waybar custom module for remote builders + cache status

set -euo pipefail

BUILDER_STATUS_FILE="/run/builder-status/status.json"
CACHE_STATUS_FILE="/run/cache-status/status.json"
NIKS3_URL_FILE="/run/niks3-server-url"
QUEUE_PENDING_DIR="/var/lib/cache-upload-queue/pending"
QUEUE_DONE_DIR="/var/lib/cache-upload-queue/done"

BUILDER_ICON=$'\uf233' # nf-fa-server
CACHE_ON=$'\uf1c0'     # nf-fa-database
CACHE_OFF=$'\uf1c0'    # same icon, styled via class

# Output JSON for waybar
output_json() {
  local text="$1"
  local tooltip="$2"
  local class="$3"

  jq -cn \
    --arg text "$text" \
    --arg tooltip "$tooltip" \
    --arg class "$class" \
    '{text: $text, tooltip: $tooltip, class: $class}'
}

# --- Builders ---
builder_text=""
builder_tooltip=""
builder_active=false

if [[ -s "$BUILDER_STATUS_FILE" ]]; then
  builders=$(cat "$BUILDER_STATUS_FILE")
  regular_count=$(echo "$builders" | jq '[.[] | select(.name | startswith("big-") | not) | select(.name | startswith("builder-"))] | length')
  big_count=$(echo "$builders" | jq '[.[] | select(.name | startswith("big-builder-"))] | length')
  total=$((regular_count + big_count))

  if [[ "$total" -gt 0 ]]; then
    builder_active=true

    if [[ "$big_count" -gt 0 ]] && [[ "$regular_count" -gt 0 ]]; then
      display="${regular_count}+${big_count}"
    elif [[ "$big_count" -gt 0 ]]; then
      display="0+${big_count}"
    else
      display="$regular_count"
    fi

    builder_text="$BUILDER_ICON  $display"
    builder_tooltip=$(echo "$builders" | jq -r '
      (
        [.[] | select(.name | startswith("big-") | not) | select(.name | startswith("builder-"))] |
        if length > 0 then
          "Regular Builders:\n" + (map("  \(.name): \(.public_net.ipv4.ip // "pending")") | join("\n"))
        else ""
        end
      ) as $regular |
      (
        [.[] | select(.name | startswith("big-builder-"))] |
        if length > 0 then
          "Big-Parallel Builders:\n" + (map("  \(.name): \(.public_net.ipv4.ip // "pending")") | join("\n"))
        else ""
        end
      ) as $big |
      [$regular, $big] | map(select(. != "")) | join("\n\n")
    ')
  fi
fi

if [[ -z "$builder_tooltip" ]]; then
  builder_tooltip="No active builders"
fi

# --- Upload queue ---
queued=0
uploaded=0
upload_status="unknown"
if [[ -d "$QUEUE_PENDING_DIR" ]]; then
  queued=$(find "$QUEUE_PENDING_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
fi
if [[ -d "$QUEUE_DONE_DIR" ]]; then
  uploaded=$(find "$QUEUE_DONE_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
fi
# Check last upload service result
upload_result=$(systemctl show cache-upload.service --property=Result --value 2>/dev/null || echo "unknown")
upload_active=$(systemctl is-active cache-upload.service 2>/dev/null || echo "unknown")
if [[ "$upload_active" == "activating" ]]; then
  upload_status="running"
elif [[ "$upload_result" == "success" ]]; then
  upload_status="ok"
elif [[ "$upload_result" == "exit-code" ]]; then
  upload_status="failed"
fi

# --- Cache ---
cache_ok=false
cache_tooltip="Cache: inactive"

if [[ -s "$CACHE_STATUS_FILE" ]]; then
  server_count=$(jq 'length' < "$CACHE_STATUS_FILE")
  if [[ "$server_count" -gt 0 ]]; then
    server_status=$(jq -r '.[0].status // "unknown"' < "$CACHE_STATUS_FILE")
    server_name=$(jq -r '.[0].name // "cache"' < "$CACHE_STATUS_FILE")
    server_ip=$(jq -r '.[0].public_net.ipv4.ip // "pending"' < "$CACHE_STATUS_FILE")

    if [[ "$server_status" == "running" ]] && [[ -f "$NIKS3_URL_FILE" ]]; then
      cache_ok=true
      cache_tooltip="Cache: ${server_name} (${server_ip})"
    elif [[ "$server_status" == "running" ]]; then
      cache_tooltip="Cache: ${server_name} (tunnel down)"
    else
      cache_tooltip="Cache: ${server_name} (${server_status})"
    fi
  fi
fi

queue_tooltip="Queue: ${queued} pending, ${uploaded} uploaded (last upload: ${upload_status})"
cache_tooltip="${cache_tooltip}
${queue_tooltip}"

# --- Combine ---
tooltip="${builder_tooltip}
${cache_tooltip}"

UPLOAD_FAIL=$'\uf071' # nf-fa-warning

if $cache_ok; then
  if [[ "$upload_status" == "failed" ]]; then
    cache_text="$CACHE_ON $UPLOAD_FAIL ${queued}"
  elif [[ "$queued" -gt 0 ]]; then
    cache_text="$CACHE_ON ${queued}"
  else
    cache_text="$CACHE_ON"
  fi
else
  if [[ "$upload_status" == "failed" ]]; then
    cache_text="$UPLOAD_FAIL ${queued}"
  elif [[ "$queued" -gt 0 ]]; then
    cache_text="${queued}"
  else
    cache_text=""
  fi
fi

if [[ -n "$builder_text" ]] && [[ -n "$cache_text" ]]; then
  text="$builder_text  $cache_text"
elif [[ -n "$builder_text" ]]; then
  text="$builder_text"
elif [[ -n "$cache_text" ]]; then
  text="$cache_text"
else
  output_json "" "$tooltip" "idle"
  exit 0
fi

if [[ "$upload_status" == "failed" ]]; then
  class="warning"
elif $builder_active && $cache_ok; then
  class="active"
elif $builder_active || $cache_ok; then
  class="partial"
else
  class="idle"
fi

output_json "$text" "$tooltip" "$class"
