#!/usr/bin/env bash
# modules/common/sway/waybar/waybar-ai-spend.sh
# Waybar custom module -- reads cached AI spend data and outputs waybar JSON

set -euo pipefail

AI_SPEND_STATUS_FILE="/run/ai-spend-status/status.json"
AI_ICON=$'\U000F0109' # nf-md-brain (󰄉)

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

# Handle missing status file
if [[ ! -s "$AI_SPEND_STATUS_FILE" ]]; then
  output_json "${AI_ICON} --" "AI Spend: no data available" "error"
  exit 0
fi

# Read the status file
status=$(< "$AI_SPEND_STATUS_FILE")

# Check for top-level error (malformed JSON guard)
if ! echo "$status" | jaq -e '.' > /dev/null 2>&1; then
  output_json "${AI_ICON} err" "AI Spend: invalid status file" "error"
  exit 0
fi

# Check for Exa-level error
exa_error=$(echo "$status" | jaq -r '.exa.error // empty' 2>/dev/null || true)
if [[ -n "$exa_error" ]]; then
  output_json "${AI_ICON} err" "AI Spend: API error — ${exa_error}" "error"
  exit 0
fi

# Extract total cost
total_cost=$(echo "$status" | jaq -r '.total_cost_usd // empty' 2>/dev/null || true)
if [[ -z "$total_cost" ]]; then
  output_json "${AI_ICON} --" "AI Spend: no data available" "error"
  exit 0
fi

# Staleness check
timestamp=$(echo "$status" | jaq -r '.timestamp // empty' 2>/dev/null || true)
class="ok"
stale_label=""
if [[ -n "$timestamp" ]]; then
  now_epoch=$(date +%s)
  data_epoch=$(date -d "$timestamp" +%s 2>/dev/null || echo "$now_epoch")
  age_seconds=$(( now_epoch - data_epoch ))
  age_minutes=$(( age_seconds / 60 ))
  if [[ $age_minutes -ge 15 ]]; then
    class="stale"
    stale_label=" ⚠ stale"
  fi
fi

# Format total cost as $X.XX
total_formatted=$(printf '$%.2f' "$total_cost")

# Build tooltip header
period_start=$(echo "$status" | jaq -r '.exa.period.start // empty' 2>/dev/null || true)
period_end=$(echo "$status" | jaq -r '.exa.period.end // empty' 2>/dev/null || true)
period_label="30 days"
if [[ -n "$period_start" ]] && [[ -n "$period_end" ]]; then
  start_fmt=$(date -d "$period_start" '+%b %d' 2>/dev/null || echo "$period_start")
  end_fmt=$(date -d "$period_end" '+%b %d' 2>/dev/null || echo "$period_end")
  period_label="${start_fmt} – ${end_fmt}"
fi

tooltip="AI Spend (${period_label})${stale_label}"

# Build Exa cost breakdown section
exa_total=$(echo "$status" | jaq -r '.exa.total_cost_usd // empty' 2>/dev/null || true)
if [[ -n "$exa_total" ]]; then
  exa_total_fmt=$(printf '$%.2f' "$exa_total")
  tooltip="${tooltip}

Exa: ${exa_total_fmt}"

  # Per-product breakdown -- extract TSV and format amounts with printf
  breakdown_tsv=$(echo "$status" | jaq -r '
    .exa.cost_breakdown[]? |
    [.price_name, (.amount_usd | tostring), (.quantity | tostring)] | join("\t")
  ' 2>/dev/null || true)

  if [[ -n "$breakdown_tsv" ]]; then
    while IFS=$'\t' read -r price_name amount_usd quantity; do
      line_fmt=$(printf '  %s: $%.2f (%s requests)' "$price_name" "$amount_usd" "$quantity")
      tooltip="${tooltip}
${line_fmt}"
    done <<< "$breakdown_tsv"
  fi
fi

# Last-updated timestamp
if [[ -n "$timestamp" ]]; then
  last_updated=$(date -d "$timestamp" '+%I:%M %p' 2>/dev/null || echo "$timestamp")
  # Strip leading zero from hour
  last_updated="${last_updated#0}"
  tooltip="${tooltip}

Last updated: ${last_updated}"
fi

output_json "${AI_ICON} ${total_formatted}" "$tooltip" "$class"
