#!/usr/bin/env bash
# shellcheck disable=SC2016 # Single-quoted strings contain jq expressions, not shell variables
# Look up a secret by its Title attribute from FDO Secret Service.
# Usage: claude-KeePassXC-lookup <entry-title>
# Returns JSON object with the secret value.
set -euo pipefail

TITLE="${1:-}"

if [[ -z "$TITLE" ]]; then
  echo '{"error": "Usage: claude-KeePassXC-lookup <entry-title>"}' >&2
  exit 1
fi

SECRET=$(@secret-tool@ lookup Title "$TITLE" 2>/dev/null) || {
  @jq@ -n --arg title "$TITLE" '{"error": "No entry found with Title=\($title). Use claude-KeePassXC-search to list available entries."}' >&2
  exit 1
}

@jq@ -n --arg title "$TITLE" --arg secret "$SECRET" '{"title": $title, "secret": $secret}'
