#!/usr/bin/env bash
set -euo pipefail
# Usage: claude-NixOSBuild-list-attempts <state_dir>
if [[ $# -ne 1 ]]; then
  echo '{"error": "Usage: claude-NixOSBuild-list-attempts <state_dir>"}' >&2
  exit 1
fi
cat "$1/attempts.log"
