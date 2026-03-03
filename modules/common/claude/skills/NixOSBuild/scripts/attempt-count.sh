#!/usr/bin/env bash
set -euo pipefail
# Usage: claude-NixOSBuild-attempt-count <state_dir>
if [[ $# -ne 1 ]]; then
  echo '{"error": "Usage: claude-NixOSBuild-attempt-count <state_dir>"}' >&2
  exit 1
fi
wc -l < "$1/attempts.log" | tr -d ' '
