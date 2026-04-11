#!/usr/bin/env bash
# modules/common/sway/waybar/ccusage-cache.sh
# Runs ccusage and caches daily token stats to $XDG_RUNTIME_DIR/ccusage-cache.json

set -euo pipefail

CACHE_FILE="${XDG_RUNTIME_DIR}/ccusage-cache.json"

raw=$(ccusage daily --json --since "$(date +%Y%m01)" --offline)

# Add a timestamp and write atomically
tmp=$(mktemp "${CACHE_FILE}.XXXXXX")
# shellcheck disable=SC2016
echo "$raw" | jaq --arg ts "$(date -Iseconds)" '. + {timestamp: $ts}' > "$tmp"
mv -f "$tmp" "$CACHE_FILE"
