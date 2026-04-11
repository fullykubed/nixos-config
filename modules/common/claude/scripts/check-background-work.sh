#!/usr/bin/env bash
# Workmux pre_merge hook: block merge if any background summary agents are running.
# Exit 0 = clear to merge. Exit 1 = background work in progress.

set -euo pipefail

shopt -s nullglob
files=(.claude/background/*)

if [[ ${#files[@]} -gt 0 ]]; then
  echo ":: Error: ${#files[@]} background summary agent(s) still running." \
       "Wait for completion before merging." >&2
  exit 1
fi
