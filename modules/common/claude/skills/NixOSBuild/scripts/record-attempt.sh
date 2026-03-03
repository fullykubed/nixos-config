#!/usr/bin/env bash
set -euo pipefail
# Usage: claude-NixOSBuild-record-attempt <state_dir> <error_signature> <classification>
if [[ $# -ne 3 ]]; then
  echo '{"error": "Usage: claude-NixOSBuild-record-attempt <state_dir> <error_signature> <classification>"}' >&2
  exit 1
fi
printf '%s\t%s\t%s\n' "$(date -Iseconds)" "$2" "$3" >> "$1/attempts.log"
