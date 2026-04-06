#!/usr/bin/env bash
# modules/common/sway/waybar/waybar-ai-spend.sh
# Waybar custom module -- reads cached AI spend data and outputs waybar JSON

set -euo pipefail

AI_SPEND_STATUS_FILE="/run/ai-spend-status/status.json"
AI_ICON=$'\U000F06A9' # nf-md-robot (󰚩)

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
  output_json "${AI_ICON}  --" "AI Spend: no data available" "error"
  exit 0
fi

# Read the status file
status=$(< "$AI_SPEND_STATUS_FILE")

# Check for top-level error (malformed JSON guard)
if ! echo "$status" | jaq -e '.' > /dev/null 2>&1; then
  output_json "${AI_ICON}  err" "AI Spend: invalid status file" "error"
  exit 0
fi

# Check for Exa-level error
exa_error=$(echo "$status" | jaq -r '.exa.error // empty' 2>/dev/null || true)
if [[ -n "$exa_error" ]]; then
  output_json "${AI_ICON}  err" "AI Spend: API error — ${exa_error}" "error"
  exit 0
fi

# Extract total cost
total_cost=$(echo "$status" | jaq -r '.total_cost_usd // empty' 2>/dev/null || true)
if [[ -z "$total_cost" ]]; then
  output_json "${AI_ICON}  --" "AI Spend: no data available" "error"
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

# ------------------------------------------------------------------------------
# Headroom stats (from status file, collected by ai-spend-status service)
# ------------------------------------------------------------------------------

# Format token count with K/M suffix
fmt_tokens() {
  local n=$1
  if (( n >= 1000000 )); then
    # shellcheck disable=SC2016
    jaq -rn --argjson n "$n" '($n / 1000000 * 10 | round) / 10 | tostring + "M"'
  elif (( n >= 1000 )); then
    # shellcheck disable=SC2016
    jaq -rn --argjson n "$n" '($n / 1000 | round | tostring) + "K"'
  else
    echo "$n"
  fi
}

# Format model name: "claude-sonnet-4-6" -> "Sonnet 4.6"
fmt_model() {
  local m=$1
  m=${m#claude-}
  m=${m%%-[0-9][0-9][0-9][0-9][0-9]*}
  local name version
  case $m in
    haiku-*)  name="Haiku";  version="${m#haiku-}" ;;
    opus-*)   name="Opus";   version="${m#opus-}" ;;
    sonnet-*) name="Sonnet"; version="${m#sonnet-}" ;;
    *)        echo "$m"; return ;;
  esac
  echo "${name} ${version//-/.}"
}

hr_error=$(echo "$status" | jaq -r '.headroom.error // empty' 2>/dev/null || true)

if [[ -z "$hr_error" ]] && echo "$status" | jaq -e '.headroom.session' > /dev/null 2>&1; then
  # 30-day totals
  td_requests=$(echo "$status" | jaq -r '.headroom.thirty_day.requests // 0')
  td_cache=$(echo "$status" | jaq -r '.headroom.thirty_day.cache_savings_usd // 0')
  td_compress=$(echo "$status" | jaq -r '.headroom.thirty_day.compress_savings_usd // 0')
  td_tokens=$(echo "$status" | jaq -r '.headroom.thirty_day.tokens_saved // 0')

  # shellcheck disable=SC2016
  td_total_saved=$(jaq -rn --argjson a "$td_cache" --argjson b "$td_compress" '$a + $b')
  td_total_fmt=$(printf '$%.2f' "$td_total_saved")
  td_cache_fmt=$(printf '$%.2f' "$td_cache")
  td_compress_fmt=$(printf '$%.2f' "$td_compress")

  tooltip="${tooltip}

Headroom – 30 day
  ${td_total_fmt} saved (${td_requests} req)
  Cache: ${td_cache_fmt}  |  Compression: ${td_compress_fmt}, $(fmt_tokens "$td_tokens") tokens"

  # Session stats
  s_requests=$(echo "$status" | jaq -r '.headroom.session.requests // 0')
  s_cache=$(echo "$status" | jaq -r '.headroom.session.cache_savings_usd // 0')
  s_compress=$(echo "$status" | jaq -r '.headroom.session.compress_savings_usd // 0')
  s_overhead=$(echo "$status" | jaq -r '.headroom.session.avg_overhead_ms // 0')
  s_hit_rate=$(echo "$status" | jaq -r '.headroom.session.cache_hit_rate // 0')

  # shellcheck disable=SC2016
  s_total_saved=$(jaq -rn --argjson a "$s_cache" --argjson b "$s_compress" '$a + $b')
  s_total_fmt=$(printf '$%.2f' "$s_total_saved")
  s_overhead_fmt=$(printf '%.0f' "$s_overhead")

  tooltip="${tooltip}

Headroom – session
  ${s_total_fmt} saved (${s_requests} req, ${s_overhead_fmt}ms overhead)
  Cache: ${s_hit_rate}% hit rate"

  # Per-model breakdown from session data
  # shellcheck disable=SC2016
  model_tsv=$(echo "$status" | jaq -r '
    .headroom.session.per_model | to_entries[] |
    [.key, (.value.requests | tostring), (.value.reduction_pct | tostring)] | join("\t")
  ' 2>/dev/null || true)

  if [[ -n "$model_tsv" ]]; then
    while IFS=$'\t' read -r model requests reduction; do
      [[ -z "$model" ]] && continue
      model_name=$(fmt_model "$model")
      tooltip="${tooltip}
  ${model_name}: ${requests} req, ${reduction}% reduced"
    done <<< "$model_tsv"
  fi
fi

# ------------------------------------------------------------------------------
# Claude Code token stats (from ccusage-cache systemd timer)
# ------------------------------------------------------------------------------

CCUSAGE_CACHE="${XDG_RUNTIME_DIR}/ccusage-cache.json"

if [[ -s "$CCUSAGE_CACHE" ]]; then
  cc_raw=$(< "$CCUSAGE_CACHE")

  if echo "$cc_raw" | jaq -e '.daily' > /dev/null 2>&1; then
    cc_count=$(echo "$cc_raw" | jaq '.daily | length')

    if (( cc_count > 0 )); then
      # Today = last entry in the daily array
      cc_today=$(echo "$cc_raw" | jaq '.daily[-1]')

      t_input=$(echo "$cc_today" | jaq -r '.inputTokens // 0')
      t_output=$(echo "$cc_today" | jaq -r '.outputTokens // 0')
      t_cache_read=$(echo "$cc_today" | jaq -r '.cacheReadTokens // 0')
      t_cache_write=$(echo "$cc_today" | jaq -r '.cacheCreationTokens // 0')
      t_total=$(echo "$cc_today" | jaq -r '.totalTokens // 0')

      if (( t_total > 0 )); then
        tooltip="${tooltip}

Claude Code – today
  $(fmt_tokens "$t_total") total ($(fmt_tokens "$t_input") in, $(fmt_tokens "$t_output") out)
  Cache: $(fmt_tokens "$t_cache_read") read, $(fmt_tokens "$t_cache_write") write"

        # Per-model breakdown for today
        # shellcheck disable=SC2016
        cc_model_tsv=$(echo "$cc_today" | jaq -r '
          .modelBreakdowns[]? |
          [.modelName, (.inputTokens | tostring), (.outputTokens | tostring),
           (.cacheReadTokens | tostring), (.cacheCreationTokens | tostring),
           ((.inputTokens + .outputTokens + .cacheReadTokens + .cacheCreationTokens) | tostring)] |
          join("\t")
        ' 2>/dev/null || true)

        if [[ -n "$cc_model_tsv" ]]; then
          while IFS=$'\t' read -r model input output _cache_r _cache_w model_total; do
            [[ -z "$model" ]] && continue
            model_name=$(fmt_model "$model")
            tooltip="${tooltip}
  ${model_name}: $(fmt_tokens "$model_total") ($(fmt_tokens "$input") in, $(fmt_tokens "$output") out)"
          done <<< "$cc_model_tsv"
        fi
      fi

      # Monthly total (sum all entries)
      # shellcheck disable=SC2016
      monthly_total=$(echo "$cc_raw" | jaq '[.daily[].totalTokens] | add // 0')

      if (( monthly_total > 0 )); then
        month_name=$(date '+%B')
        tooltip="${tooltip}

Claude Code – ${month_name}
  $(fmt_tokens "$monthly_total") total tokens"
      fi
    fi
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

output_json "${AI_ICON}  ${total_formatted}" "$tooltip" "$class"
