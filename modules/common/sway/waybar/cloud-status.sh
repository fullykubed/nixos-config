#!/usr/bin/env bash
# modules/common/sway/waybar/cloud-status.sh
# Collects R2 bucket sizes from the Cloudflare GraphQL Analytics API and checks
# local ccache component health, then writes a JSON status file to
# /run/cloud-status/status.json.

set -euo pipefail

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

ACCOUNT_ID="f875b3b102f2a88a51db200ba95e1fc9"
CF_GRAPHQL_ENDPOINT="https://api.cloudflare.com/client/v4/graphql"
OUTPUT_DIR="/run/cloud-status"
OUTPUT_FILE="${OUTPUT_DIR}/status.json"
OUTPUT_TMP="${OUTPUT_DIR}/status.json.tmp"

# ------------------------------------------------------------------------------
# Logging helpers (all output goes to stderr)
# ------------------------------------------------------------------------------

info()  { echo ":: $*" >&2; }
warn()  { echo ":: Warning: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

# ------------------------------------------------------------------------------
# Setup
# ------------------------------------------------------------------------------

mkdir -p "$OUTPUT_DIR"

# ------------------------------------------------------------------------------
# R2 bucket size queries via Cloudflare GraphQL
# ------------------------------------------------------------------------------

r2_ccache_payload_size="null"
r2_ccache_object_count="null"
r2_nixos_cache_payload_size="null"
r2_nixos_cache_object_count="null"
r2_error=""

if [[ -z "${CF_API_TOKEN:-}" ]]; then
  r2_error="CF_API_TOKEN not set"
  warn "$r2_error; skipping R2 queries"
else
  info "Querying Cloudflare GraphQL API for R2 bucket sizes"

  today=$(date -u +"%Y-%m-%d")
  yesterday=$(date -u -d "yesterday" +"%Y-%m-%d")

  graphql_query=$(cat <<EOF
{
  "query": "{ viewer { accounts(filter: { accountTag: \"${ACCOUNT_ID}\" }) { ccache: r2StorageAdaptiveGroups(limit: 1, filter: { bucketName: \"ccache\", date_geq: \"${yesterday}\", date_leq: \"${today}\" }, orderBy: [date_DESC]) { max { payloadSize objectCount } } nixosCache: r2StorageAdaptiveGroups(limit: 1, filter: { bucketName: \"fullykubed-nixos-cache\", date_geq: \"${yesterday}\", date_leq: \"${today}\" }, orderBy: [date_DESC]) { max { payloadSize objectCount } } } } }"
}
EOF
)

  http_status=""
  api_response=""

  if api_response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    --data "${graphql_query}" \
    "${CF_GRAPHQL_ENDPOINT}" 2>/dev/null); then

    http_status=$(echo "$api_response" | tail -n1)
    api_body=$(echo "$api_response" | head -n -1)

    if [[ "$http_status" == "200" ]]; then
      # Check for GraphQL-level errors
      gql_errors=$(echo "$api_body" | jaq -r '.errors // empty' 2>/dev/null || true)
      if [[ -n "$gql_errors" ]] && [[ "$gql_errors" != "null" ]]; then
        gql_msg=$(echo "$api_body" | jaq -r '.errors[0].message // "unknown GraphQL error"' 2>/dev/null || echo "unknown GraphQL error")
        r2_error="GraphQL error: ${gql_msg}"
        warn "$r2_error"
      else
        info "Cloudflare API call succeeded (HTTP ${http_status})"

        # Extract ccache bucket values
        ccache_payload=$(echo "$api_body" | jaq -r \
          '.data.viewer.accounts[0].ccache[0].max.payloadSize // "null"' 2>/dev/null || echo "null")
        ccache_objects=$(echo "$api_body" | jaq -r \
          '.data.viewer.accounts[0].ccache[0].max.objectCount // "null"' 2>/dev/null || echo "null")

        # Extract nixos-cache bucket values
        nixos_payload=$(echo "$api_body" | jaq -r \
          '.data.viewer.accounts[0].nixosCache[0].max.payloadSize // "null"' 2>/dev/null || echo "null")
        nixos_objects=$(echo "$api_body" | jaq -r \
          '.data.viewer.accounts[0].nixosCache[0].max.objectCount // "null"' 2>/dev/null || echo "null")

        # Only assign if we got actual numeric values (not the literal string "null")
        [[ "$ccache_payload" != "null" ]] && r2_ccache_payload_size="$ccache_payload"
        [[ "$ccache_objects" != "null" ]]  && r2_ccache_object_count="$ccache_objects"
        [[ "$nixos_payload" != "null" ]]   && r2_nixos_cache_payload_size="$nixos_payload"
        [[ "$nixos_objects" != "null" ]]   && r2_nixos_cache_object_count="$nixos_objects"

        # If API succeeded but all values are still null, the query returned empty results
        if [[ "$r2_ccache_payload_size" == "null" ]] && [[ "$r2_nixos_cache_payload_size" == "null" ]]; then
          r2_error="API returned empty results (no data for date range ${yesterday} to ${today})"
          warn "$r2_error"
        fi
      fi
    else
      r2_error="HTTP ${http_status} from Cloudflare API"
      warn "$r2_error"
    fi
  else
    r2_error="curl failed to reach Cloudflare API"
    warn "$r2_error"
  fi
fi

# ------------------------------------------------------------------------------
# ccache local health checks
# ------------------------------------------------------------------------------

info "Checking ccache local health"

# 1. Local cache directory
if [[ -d /var/cache/ccache ]]; then
  ccache_local_dir="true"
else
  ccache_local_dir="false"
fi

# 2. R2 mount
if mountpoint -q /var/cache/ccache-r2 2>/dev/null; then
  ccache_r2_mount="true"
else
  ccache_r2_mount="false"
fi

# 3. Sync timer
sync_timer_state=$(systemctl is-active ccache-r2-sync.timer 2>/dev/null || echo "inactive")
if [[ "$sync_timer_state" == "active" ]]; then
  ccache_sync_timer="true"
else
  ccache_sync_timer="false"
fi

# 4. ccache stats via nix-ccache setgid wrapper
ccache_stats_json="null"
if stats_output=$(nix-ccache --print-stats 2>/dev/null); then
  # Parse hit rate (supports both "cache hit ratio" and "hit rate" labels)
  hit_rate=""
  if hit_line=$(echo "$stats_output" | grep -i "hit rate\|cache hit ratio" | head -n1); then
    hit_rate=$(echo "$hit_line" | grep -oP '\d+(\.\d+)?%' | head -n1 || true)
  fi

  # Parse cache size
  cache_size=""
  if size_line=$(echo "$stats_output" | grep -i "cache size" | head -n1); then
    cache_size=$(echo "$size_line" | grep -oP '\d+(\.\d+)?\s*(GB|MB|KB|TB|B)' | head -n1 || true)
  fi

  # Parse total requests ("Cacheable calls" in ccache 4.x+)
  total_requests=""
  if req_line=$(echo "$stats_output" | grep -i "cacheable calls\|total requests" | head -n1); then
    total_requests=$(echo "$req_line" | grep -oP '\d+' | tail -n1 || true)
  fi

  if [[ -n "$hit_rate" ]] || [[ -n "$cache_size" ]] || [[ -n "$total_requests" ]]; then
    # shellcheck disable=SC2016
    ccache_stats_json=$(jaq -cn \
      --arg hitRate "${hit_rate}" \
      --arg cacheSize "${cache_size}" \
      --arg totalRequests "${total_requests}" \
      '{hitRate: $hitRate, cacheSize: $cacheSize, totalRequests: $totalRequests}')
  fi
fi

# ------------------------------------------------------------------------------
# Build R2 sub-objects (null when data was unavailable)
# ------------------------------------------------------------------------------

if [[ "$r2_ccache_payload_size" == "null" ]] && [[ "$r2_ccache_object_count" == "null" ]]; then
  r2_ccache_json="null"
else
  # shellcheck disable=SC2016
  r2_ccache_json=$(jaq -cn \
    --argjson payloadSize "${r2_ccache_payload_size}" \
    --argjson objectCount "${r2_ccache_object_count}" \
    '{payloadSize: $payloadSize, objectCount: $objectCount}')
fi

if [[ "$r2_nixos_cache_payload_size" == "null" ]] && [[ "$r2_nixos_cache_object_count" == "null" ]]; then
  r2_nixos_json="null"
else
  # shellcheck disable=SC2016
  r2_nixos_json=$(jaq -cn \
    --argjson payloadSize "${r2_nixos_cache_payload_size}" \
    --argjson objectCount "${r2_nixos_cache_object_count}" \
    '{payloadSize: $payloadSize, objectCount: $objectCount}')
fi

# ------------------------------------------------------------------------------
# Write output JSON atomically
# ------------------------------------------------------------------------------

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

info "Writing status to ${OUTPUT_FILE}"

# Build r2Error as either a JSON string or null
if [[ -n "$r2_error" ]]; then
  # shellcheck disable=SC2016
  r2_error_json=$(jaq -cn --arg e "$r2_error" '$e')
else
  r2_error_json="null"
fi

# shellcheck disable=SC2016
jaq -cn \
  --argjson r2Ccache "${r2_ccache_json}" \
  --argjson r2NixosCache "${r2_nixos_json}" \
  --argjson r2Error "${r2_error_json}" \
  --argjson localDir "${ccache_local_dir}" \
  --argjson r2Mount "${ccache_r2_mount}" \
  --argjson syncTimer "${ccache_sync_timer}" \
  --argjson stats "${ccache_stats_json}" \
  --arg timestamp "${timestamp}" \
  '{
    r2: {
      ccache: $r2Ccache,
      "nixos-cache": $r2NixosCache,
      error: $r2Error
    },
    ccache: {
      localDir: $localDir,
      r2Mount: $r2Mount,
      syncTimer: $syncTimer,
      stats: $stats
    },
    timestamp: $timestamp
  }' > "${OUTPUT_TMP}"

chmod 0644 "${OUTPUT_TMP}"
mv "${OUTPUT_TMP}" "${OUTPUT_FILE}"

info "cloud-status: done"
