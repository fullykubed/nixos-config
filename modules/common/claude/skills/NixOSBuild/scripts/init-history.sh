#!/usr/bin/env bash
set -euo pipefail
# Usage: claude-NixOSBuild-init-history <worktree>
if [[ $# -ne 1 ]]; then
  echo '{"error": "Usage: claude-NixOSBuild-init-history <worktree>"}' >&2
  exit 1
fi
dir="/tmp/nixos-build/$1"
mkdir -p "$dir"
: > "$dir/attempts.log"
echo "$dir"
