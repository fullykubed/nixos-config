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
  --arg timestamp "${timestamp}" \
  '{
    exa: {
      total_cost_usd: $exaTotalCost,
      cost_breakdown: $exaCostBreakdown,
      key_count: $exaKeyCount,
      period: $exaPeriod,
      error: $exaError
    },
    total_cost_usd: $exaTotalCost,
    timestamp: $timestamp
  }' > "${OUTPUT_TMP}"

chmod 0644 "${OUTPUT_TMP}"
mv "${OUTPUT_TMP}" "${OUTPUT_FILE}"

info "ai-spend-status: done"
