#!/usr/bin/env bash
# modules/common/sway/waybar/ai-spend-status.sh
# Queries the Exa admin API for billing data across all API keys and writes
# aggregated spend information to /run/ai-spend-status/status.json.

set -euo pipefail

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

EXA_API_BASE="https://admin-api.exa.ai/team-management"
OUTPUT_DIR="/run/ai-spend-status"
OUTPUT_FILE="${OUTPUT_DIR}/status.json"
OUTPUT_TMP="${OUTPUT_DIR}/status.json.tmp"
STATE_DIR="/var/lib/ai-spend-status"
HEADROOM_FILE="${STATE_DIR}/headroom.json"
HEADROOM_URL="http://127.0.0.1:8787/stats"
PRUNE_DAYS=30

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
# Exa API: collect spend data across all API keys
# ------------------------------------------------------------------------------

exa_total_cost="0"
exa_cost_breakdown_json="[]"
exa_key_count="0"
exa_period_start=""
exa_period_end=""
exa_error=""

if [[ -z "${EXA_API_TOKEN:-}" ]]; then
  exa_error="EXA_API_TOKEN not set"
  warn "$exa_error; skipping Exa queries"
else
  info "Querying Exa admin API for API keys"

  # Step 1: Discover all API key UUIDs
  api_response=""
  if api_response=$(curl -s -w "\n%{http_code}" \
    -X GET \
    -H "x-api-key: ${EXA_API_TOKEN}" \
    "${EXA_API_BASE}/api-keys" 2>/dev/null); then

    http_status=$(echo "$api_response" | tail -n1)
    api_body=$(echo "$api_response" | head -n -1)

    if [[ "$http_status" == "200" ]]; then
      # Extract key IDs from the response
      key_ids=""
      key_ids=$(echo "$api_body" | jaq -r '.apiKeys[].id' 2>/dev/null || true)

      if [[ -z "$key_ids" ]]; then
        exa_error="No API keys found in Exa account"
        warn "$exa_error"
      else
        info "Discovered Exa API keys: $(echo "$key_ids" | wc -l | tr -d ' ') key(s)"

        # Step 2: Query usage for each discovered API key
        while IFS= read -r key_id; do
          [[ -z "$key_id" ]] && continue

          info "Fetching usage for key: ${key_id}"

          usage_response=""
          if usage_response=$(curl -s -w "\n%{http_code}" \
            -X GET \
            -H "x-api-key: ${EXA_API_TOKEN}" \
            "${EXA_API_BASE}/api-keys/${key_id}/usage" 2>/dev/null); then

            usage_status=$(echo "$usage_response" | tail -n1)
            usage_body=$(echo "$usage_response" | head -n -1)

            if [[ "$usage_status" == "200" ]]; then
              info "Usage fetch succeeded for key ${key_id} (HTTP ${usage_status})"

              # Extract cost from this key
              key_cost=$(echo "$usage_body" | jaq -r '.total_cost_usd // 0' 2>/dev/null || echo "0")
              key_breakdown=$(echo "$usage_body" | jaq -c '.cost_breakdown // []' 2>/dev/null || echo "[]")

              # Capture period from first successful key
              if [[ -z "$exa_period_start" ]]; then
                exa_period_start=$(echo "$usage_body" | jaq -r '.period.start // ""' 2>/dev/null || true)
                exa_period_end=$(echo "$usage_body" | jaq -r '.period.end // ""' 2>/dev/null || true)
              fi

              # Accumulate total cost (add key_cost to running total)
              # shellcheck disable=SC2016
              exa_total_cost=$(jaq -cn \
                --argjson a "${exa_total_cost}" \
                --argjson b "${key_cost}" \
                '$a + $b')

              # Merge cost_breakdown: combine entries with the same price_name
              # by summing quantity and amount_usd
              # shellcheck disable=SC2016
              exa_cost_breakdown_json=$(jaq -cn \
                --argjson existing "${exa_cost_breakdown_json}" \
                --argjson incoming "${key_breakdown}" \
                '($existing + $incoming)
                 | group_by(.price_name)
                 | map({
                     price_name: .[0].price_name,
                     quantity: map(.quantity) | add,
                     amount_usd: map(.amount_usd) | add
                   })')

              exa_key_count=$(( exa_key_count + 1 ))
            else
              warn "HTTP ${usage_status} from Exa usage API for key ${key_id}"
              # Continue processing remaining keys; don't set exa_error yet
            fi
          else
            warn "curl failed to reach Exa usage API for key ${key_id}"
          fi
        done <<< "$key_ids"

        # If we processed zero keys successfully, set an error
        if [[ "$exa_key_count" -eq 0 ]]; then
          exa_error="Failed to fetch usage data for any API key"
          warn "$exa_error"
        fi
      fi
    else
      exa_error="HTTP ${http_status} from Exa List API Keys endpoint"
      warn "$exa_error"
    fi
  else
    exa_error="curl failed to reach Exa admin API"
    warn "$exa_error"
  fi
fi

# ------------------------------------------------------------------------------
# Headroom proxy: collect session stats and accumulate 30-day deltas
# ------------------------------------------------------------------------------

mkdir -p "$STATE_DIR"

hr_session_json="null"
hr_thirty_day_json="null"
hr_error=""

info "Querying headroom proxy at ${HEADROOM_URL}"

headroom_raw=""
if headroom_raw=$(curl -sf --max-time 5 "$HEADROOM_URL" 2>/dev/null); then
  # Extract session counters from live proxy
  hr_requests=$(echo "$headroom_raw" | jaq -r '.requests.total // 0')
  hr_cache_usd=$(echo "$headroom_raw" | jaq -r '.cost.cache_savings_usd // 0')
  hr_compress_usd=$(echo "$headroom_raw" | jaq -r '.cost.compression_savings_usd // 0')
  hr_tokens=$(echo "$headroom_raw" | jaq -r '.cost.total_tokens_saved // 0')
  hr_avg_overhead=$(echo "$headroom_raw" | jaq -r '.overhead.average_ms // 0')
  hr_cache_hit_rate=$(echo "$headroom_raw" | jaq -r '.prefix_cache.totals.hit_rate // 0')

  # Per-model breakdown (filter to claude-* models only)
  # shellcheck disable=SC2016
  hr_per_model=$(echo "$headroom_raw" | jaq -c '
    .cost.per_model | to_entries
    | map(select(.key | startswith("claude-")))
    | map({key: .key, value: {requests: .value.requests, reduction_pct: .value.reduction_pct}})
    | from_entries
  ' 2>/dev/null || echo '{}')

  # Build session JSON
  # shellcheck disable=SC2016
  hr_session_json=$(jaq -cn \
    --argjson requests "$hr_requests" \
    --argjson cache_usd "$hr_cache_usd" \
    --argjson compress_usd "$hr_compress_usd" \
    --argjson tokens "$hr_tokens" \
    --argjson overhead "$hr_avg_overhead" \
    --argjson hit_rate "$hr_cache_hit_rate" \
    --argjson per_model "$hr_per_model" \
    '{
      requests: $requests,
      cache_savings_usd: $cache_usd,
      compress_savings_usd: $compress_usd,
      tokens_saved: $tokens,
      avg_overhead_ms: $overhead,
      cache_hit_rate: $hit_rate,
      per_model: $per_model
    }')

  # --------------------------------------------------------------------------
  # Delta accumulation against persistent history
  # --------------------------------------------------------------------------

  now_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Read existing history (or start fresh)
  if [[ -f "$HEADROOM_FILE" ]] && jaq -e '.' "$HEADROOM_FILE" > /dev/null 2>&1; then
    history=$(< "$HEADROOM_FILE")
  else
    history='{"last":{"requests":0,"cache_usd":0,"compress_usd":0,"tokens":0},"deltas":[]}'
  fi

  last_requests=$(echo "$history" | jaq -r '.last.requests // 0')
  last_cache=$(echo "$history" | jaq -r '.last.cache_usd // 0')
  last_compress=$(echo "$history" | jaq -r '.last.compress_usd // 0')
  last_tokens=$(echo "$history" | jaq -r '.last.tokens // 0')

  # Detect proxy restart: if any current value < last snapshot, proxy reset
  # shellcheck disable=SC2016
  restarted=$(jaq -rn \
    --argjson cr "$hr_requests" --argjson lr "$last_requests" \
    --argjson cc "$hr_cache_usd" --argjson lc "$last_cache" \
    --argjson cp "$hr_compress_usd" --argjson lp "$last_compress" \
    --argjson ct "$hr_tokens" --argjson lt "$last_tokens" \
    'if ($cr < $lr) or ($cc < $lc) or ($cp < $lp) or ($ct < $lt) then "yes" else "no" end')

  if [[ "$restarted" == "yes" ]]; then
    info "Headroom proxy restart detected; using current values as delta"
    d_requests="$hr_requests"
    d_cache="$hr_cache_usd"
    d_compress="$hr_compress_usd"
    d_tokens="$hr_tokens"
  else
    # shellcheck disable=SC2016
    d_requests=$(jaq -rn --argjson a "$hr_requests" --argjson b "$last_requests" '$a - $b')
    # shellcheck disable=SC2016
    d_cache=$(jaq -rn --argjson a "$hr_cache_usd" --argjson b "$last_cache" '$a - $b')
    # shellcheck disable=SC2016
    d_compress=$(jaq -rn --argjson a "$hr_compress_usd" --argjson b "$last_compress" '$a - $b')
    # shellcheck disable=SC2016
    d_tokens=$(jaq -rn --argjson a "$hr_tokens" --argjson b "$last_tokens" '$a - $b')
  fi

  # Only append a delta entry if something changed
  # shellcheck disable=SC2016
  has_change=$(jaq -rn \
    --argjson r "$d_requests" --argjson c "$d_cache" \
    --argjson p "$d_compress" --argjson t "$d_tokens" \
    'if ($r > 0) or ($c > 0) or ($p > 0) or ($t > 0) then "yes" else "no" end')

  if [[ "$has_change" == "yes" ]]; then
    # shellcheck disable=SC2016
    new_delta=$(jaq -cn \
      --arg ts "$now_iso" \
      --argjson requests "$d_requests" \
      --argjson cache_usd "$d_cache" \
      --argjson compress_usd "$d_compress" \
      --argjson tokens "$d_tokens" \
      '{ts: $ts, requests: $requests, cache_usd: $cache_usd, compress_usd: $compress_usd, tokens: $tokens}')

    # shellcheck disable=SC2016
    history=$(echo "$history" | jaq -c --argjson d "$new_delta" '.deltas += [$d]')
  fi

  # Update last snapshot
  # shellcheck disable=SC2016
  history=$(echo "$history" | jaq -c \
    --argjson r "$hr_requests" \
    --argjson c "$hr_cache_usd" \
    --argjson p "$hr_compress_usd" \
    --argjson t "$hr_tokens" \
    '.last = {requests: $r, cache_usd: $c, compress_usd: $p, tokens: $t}')

  # Prune deltas older than 30 days
  cutoff=$(date -u -d "${PRUNE_DAYS} days ago" +"%Y-%m-%dT%H:%M:%SZ")
  # shellcheck disable=SC2016
  history=$(echo "$history" | jaq -c --arg cutoff "$cutoff" \
    '.deltas |= map(select(.ts >= $cutoff))')

  # Write updated history atomically
  headroom_tmp="${HEADROOM_FILE}.tmp"
  echo "$history" > "$headroom_tmp"
  mv "$headroom_tmp" "$HEADROOM_FILE"

  # Sum 30-day totals from all deltas
  # shellcheck disable=SC2016
  hr_thirty_day_json=$(echo "$history" | jaq -c '
    .deltas | {
      requests: (map(.requests) | add // 0),
      cache_savings_usd: (map(.cache_usd) | add // 0),
      compress_savings_usd: (map(.compress_usd) | add // 0),
      tokens_saved: (map(.tokens) | add // 0)
    }')

  info "Headroom: session=${hr_requests} req, 30d delta entries=$(echo "$history" | jaq '.deltas | length')"
else
  hr_error="headroom proxy unreachable"
  warn "$hr_error"
fi

# Build headroom error field
if [[ -n "$hr_error" ]]; then
  # shellcheck disable=SC2016
  hr_error_json=$(jaq -cn --arg e "$hr_error" '$e')
else
  hr_error_json="null"
fi

# shellcheck disable=SC2016
headroom_json=$(jaq -cn \
  --argjson session "$hr_session_json" \
  --argjson thirty_day "$hr_thirty_day_json" \
  --argjson err "$hr_error_json" \
  '{session: $session, thirty_day: $thirty_day, error: $err}')

# ------------------------------------------------------------------------------
# Build output JSON
# ------------------------------------------------------------------------------

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

info "Writing status to ${OUTPUT_FILE}"

# Build the exa error field as a JSON string or null
if [[ -n "$exa_error" ]]; then
  # shellcheck disable=SC2016
  exa_error_json=$(jaq -cn --arg e "$exa_error" '$e')
else
  exa_error_json="null"
fi

# Build the exa period field (null when no successful calls)
if [[ -n "$exa_period_start" ]] && [[ -n "$exa_period_end" ]]; then
  # shellcheck disable=SC2016
  exa_period_json=$(jaq -cn \
    --arg start "$exa_period_start" \
    --arg end "$exa_period_end" \
    '{start: $start, end: $end}')
else
  exa_period_json="null"
fi

# When there was an error, zero out numeric fields
if [[ -n "$exa_error" ]]; then
  exa_total_cost="0"
  exa_cost_breakdown_json="[]"
fi

# shellcheck disable=SC2016
jaq -cn \
  --argjson exaTotalCost "${exa_total_cost}" \
  --argjson exaCostBreakdown "${exa_cost_breakdown_json}" \
  --argjson exaKeyCount "${exa_key_count}" \
  --argjson exaPeriod "${exa_period_json}" \
  --argjson exaError "${exa_error_json}" \
  --argjson headroom "${headroom_json}" \
  --arg timestamp "${timestamp}" \
  '{
    exa: {
      total_cost_usd: $exaTotalCost,
      cost_breakdown: $exaCostBreakdown,
      key_count: $exaKeyCount,
      period: $exaPeriod,
      error: $exaError
    },
    headroom: $headroom,
    total_cost_usd: $exaTotalCost,
    timestamp: $timestamp
  }' > "${OUTPUT_TMP}"

chmod 0644 "${OUTPUT_TMP}"
mv "${OUTPUT_TMP}" "${OUTPUT_FILE}"

info "ai-spend-status: done"
