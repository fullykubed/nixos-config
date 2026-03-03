#!/usr/bin/env bash
set -euo pipefail
# Exit 0 = already tried (circular), exit 1 = not yet tried
# Usage: claude-NixOSBuild-check-attempt <state_dir> <error_signature> <classification>
if [[ $# -ne 3 ]]; then
  echo '{"error": "Usage: claude-NixOSBuild-check-attempt <state_dir> <error_signature> <classification>"}' >&2
  exit 1
fi
grep -qF "$(printf '\t%s\t%s' "$2" "$3")" "$1/attempts.log"
