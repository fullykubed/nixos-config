#!/usr/bin/env bash
# shellcheck disable=SC2016 # Single-quoted strings contain jq/awk expressions, not shell variables
# Search for entries available via FDO Secret Service.
# Usage: claude-KeePassXC-search [filter-term]
# Returns JSON array of entry titles and attributes (never passwords).
set -euo pipefail

FILTER="${1:-}"

# secret-tool search with xdg:schema returns all KeePassXC-exposed entries.
RAW=$(@secret-tool@ search --all xdg:schema org.freedesktop.Secret.Generic 2>/dev/null) || {
  @jaq@ -n '{"error": "Could not reach Secret Service. Is KeePassXC running and unlocked with FDO Secrets enabled?"}' >&2
  exit 1
}

if [[ -z "$RAW" ]]; then
  @jaq@ -n '{"entries": [], "message": "No entries found. Ensure KeePassXC has groups exposed via Database > Secret Service Integration."}'
  exit 0
fi

# Strip secret lines for safety, then parse into JSON
CLEAN=$(echo "$RAW" | @grep@ -v '^secret = ')

# Parse secret-tool output blocks into JSON array
echo "$CLEAN" | @awk@ '
BEGIN { printf "["; first=1 }
/^\[/ {
  if (!first) printf ","
  first=0
  printf "\n  {\"path\": \"%s\"", substr($0, 2, length($0)-2)
  next
}
/^label = / { printf ", \"label\": \"%s\"", substr($0, 9); next }
/^created = / { printf ", \"created\": \"%s\"", substr($0, 11); next }
/^modified = / { printf ", \"modified\": \"%s\"", substr($0, 12); next }
/^schema = / { printf ", \"schema\": \"%s\"", substr($0, 10); next }
/^attribute\./ {
  split($0, parts, " = ")
  attr = substr(parts[1], 11)
  val = parts[2]
  printf ", \"%s\": \"%s\"", attr, val
  next
}
/^$/ { printf "}"; next }
END { if (!first) printf "}"; printf "\n]\n" }
' | if [[ -n "$FILTER" ]]; then
  @jaq@ --arg f "$FILTER" '[.[] | select((.label // "") + " " + (.Title // "") | test($f; "i"))]'
else
  @jaq@ '.'
fi
