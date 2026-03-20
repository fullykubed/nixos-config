#!/usr/bin/env bash
# modules/common/sway/waybar/waybar-builders.sh
# Waybar custom module for remote builders + cache status

set -euo pipefail

BUILDER_STATUS_FILE="/run/builder-status/status.json"
CACHE_STATUS_FILE="/run/cache-status/status.json"
CLOUD_STATUS_FILE="/run/cloud-status/status.json"
NIKS3_URL_FILE="/run/niks3-server-url"
QUEUE_PENDING_DIR="/var/lib/cache-upload-queue/pending"
QUEUE_DONE_DIR="/var/lib/cache-upload-queue/done"

BUILDER_ICON=$'\uf233' # nf-fa-server
CACHE_ON=$'\uf1c0'     # nf-fa-database
# shellcheck disable=SC2034
CACHE_OFF=$'\uf1c0'    # same icon, styled via class

# Output JSON for waybar
output_json() {
  local text="$1"
  local tooltip="$2"
  local class="$3"

  # shellcheck disable=SC2016
  jaq -cn \
    --arg text "$text" \
    --arg tooltip "$tooltip" \
    --arg class "$class" \
    '{text: $text, tooltip: $tooltip, class: $class}'
}

# Convert bytes to human-readable size
format_bytes() {
  local bytes=$1
  if [[ $bytes -ge 1073741824 ]]; then
    echo "$(( bytes / 1073741824 )).$(( (bytes % 1073741824) * 10 / 1073741824 )) GB"
  elif [[ $bytes -ge 1048576 ]]; then
    echo "$(( bytes / 1048576 )) MB"
  else
    echo "$(( bytes / 1024 )) KB"
  fi
}

# --- Builders ---
builder_text=""
builder_tooltip=""
builder_active=false

if [[ -s "$BUILDER_STATUS_FILE" ]]; then
  builders=$(cat "$BUILDER_STATUS_FILE")
  regular_count=$(echo "$builders" | jaq '[.[] | select(.name | startswith("big-") | not) | select(.name | startswith("builder-"))] | length')
  big_count=$(echo "$builders" | jaq '[.[] | select(.name | startswith("big-builder-"))] | length')
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
    # shellcheck disable=SC2016
    builder_tooltip=$(echo "$builders" | jaq -r '
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
  queued=$(bfs "$QUEUE_PENDING_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
fi
if [[ -d "$QUEUE_DONE_DIR" ]]; then
  uploaded=$(bfs "$QUEUE_DONE_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
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
  # shellcheck disable=SC2016
  server_count=$(jaq 'length' < "$CACHE_STATUS_FILE")
  if [[ "$server_count" -gt 0 ]]; then
    # shellcheck disable=SC2016
    server_status=$(jaq -r '.[0].status // "unknown"' < "$CACHE_STATUS_FILE")
    # shellcheck disable=SC2016
    server_name=$(jaq -r '.[0].name // "cache"' < "$CACHE_STATUS_FILE")
    # shellcheck disable=SC2016
    server_ip=$(jaq -r '.[0].public_net.ipv4.ip // "pending"' < "$CACHE_STATUS_FILE")

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

# --- Cloud Status (R2 / ccache) ---
cloud_r2_tooltip=""
cloud_ccache_tooltip=""
ccache_healthy=true

if [[ -s "$CLOUD_STATUS_FILE" ]]; then
  # Extract R2 fields
  r2_ccache_size=$(jaq -r '.r2.ccache.payloadSize // empty' < "$CLOUD_STATUS_FILE" 2>/dev/null || true)
  r2_ccache_count=$(jaq -r '.r2.ccache.objectCount // empty' < "$CLOUD_STATUS_FILE" 2>/dev/null || true)
  r2_nixos_size=$(jaq -r '.r2."nixos-cache".payloadSize // empty' < "$CLOUD_STATUS_FILE" 2>/dev/null || true)
  r2_nixos_count=$(jaq -r '.r2."nixos-cache".objectCount // empty' < "$CLOUD_STATUS_FILE" 2>/dev/null || true)

  # Extract ccache fields
  ccache_local_dir=$(jaq -r '.ccache.localDir // empty' < "$CLOUD_STATUS_FILE" 2>/dev/null || true)
  ccache_r2_mount=$(jaq -r '.ccache.r2Mount // empty' < "$CLOUD_STATUS_FILE" 2>/dev/null || true)
  ccache_sync_timer=$(jaq -r '.ccache.syncTimer // empty' < "$CLOUD_STATUS_FILE" 2>/dev/null || true)
  ccache_hit_rate=$(jaq -r '.ccache.stats.hitRate // empty' < "$CLOUD_STATUS_FILE" 2>/dev/null || true)
  ccache_cache_size=$(jaq -r '.ccache.stats.cacheSize // empty' < "$CLOUD_STATUS_FILE" 2>/dev/null || true)

  # Extract timestamp for staleness check
  cloud_timestamp=$(jaq -r '.timestamp // empty' < "$CLOUD_STATUS_FILE" 2>/dev/null || true)

  # Staleness check
  stale_label=""
  if [[ -n "$cloud_timestamp" ]]; then
    now_epoch=$(date +%s)
    data_epoch=$(date -d "$cloud_timestamp" +%s 2>/dev/null || echo "$now_epoch")
    age_seconds=$(( now_epoch - data_epoch ))
    age_minutes=$(( age_seconds / 60 ))
    if [[ $age_minutes -ge 15 ]]; then
      stale_label=" (stale - last updated ${age_minutes} min ago)"
    fi
  fi

  # Extract error field
  r2_error=$(jaq -r '.r2.error // empty' < "$CLOUD_STATUS_FILE" 2>/dev/null || true)

  # Build R2 tooltip section
  if [[ -n "$r2_ccache_size" ]] && [[ -n "$r2_nixos_size" ]]; then
    r2_ccache_human=$(format_bytes "$r2_ccache_size")
    r2_nixos_human=$(format_bytes "$r2_nixos_size")
    r2_ccache_count_fmt=$(printf "%'.0f" "$r2_ccache_count" 2>/dev/null || echo "$r2_ccache_count")
    r2_nixos_count_fmt=$(printf "%'.0f" "$r2_nixos_count" 2>/dev/null || echo "$r2_nixos_count")
    cloud_r2_tooltip="R2 Storage${stale_label}:
  ccache: ${r2_ccache_human} (${r2_ccache_count_fmt} objects)
  nixos-cache: ${r2_nixos_human} (${r2_nixos_count_fmt} objects)"
  elif [[ -n "$r2_error" ]]; then
    cloud_r2_tooltip="R2 Storage: error — ${r2_error}"
  else
    cloud_r2_tooltip="R2 Storage: unavailable"
  fi

  # Build ccache health tooltip section
  local_dir_status="OK"
  r2_mount_status="OK"
  sync_timer_status="OK"

  if [[ "$ccache_local_dir" == "false" ]]; then
    local_dir_status="DOWN"
    ccache_healthy=false
  fi
  if [[ "$ccache_r2_mount" == "false" ]]; then
    r2_mount_status="DOWN"
    ccache_healthy=false
  fi
  if [[ "$ccache_sync_timer" == "false" ]]; then
    sync_timer_status="DOWN"
    ccache_healthy=false
  fi

  cloud_ccache_tooltip="ccache Health:
  Local cache: ${local_dir_status}
  R2 mount: ${r2_mount_status}
  Sync timer: ${sync_timer_status}"

  if [[ -n "$ccache_hit_rate" ]] && [[ -n "$ccache_cache_size" ]]; then
    cloud_ccache_tooltip="${cloud_ccache_tooltip}
  Hit rate: ${ccache_hit_rate} | Cache: ${ccache_cache_size}"
  fi
fi

# --- Combine ---
tooltip="${builder_tooltip}
${cache_tooltip}"

if [[ -n "$cloud_r2_tooltip" ]]; then
  tooltip="${tooltip}

${cloud_r2_tooltip}"
fi

if [[ -n "$cloud_ccache_tooltip" ]]; then
  tooltip="${tooltip}

${cloud_ccache_tooltip}"
fi

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

if [[ "$upload_status" == "failed" ]] || ! $ccache_healthy; then
  class="warning"
elif $builder_active && $cache_ok; then
  class="active"
elif $builder_active || $cache_ok; then
  class="partial"
else
  class="idle"
fi

output_json "$text" "$tooltip" "$class"
