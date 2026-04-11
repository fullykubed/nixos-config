#!/usr/bin/env bash
set -euo pipefail

worktree=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "error: not in a git repository" >&2; exit 1; }
worktree=$(basename "$worktree")

if ! git -C @home@/repos/nixos-config/main worktree list --porcelain | grep -q "worktree.*/${worktree}$"; then
  echo "error: '$worktree' is not a nixos-config worktree" >&2
  exit 1
fi

hostname=$(@hostname@)
CLAUDE_NO_SUMMARY=1 claude-wrapper "/NixOSBuild $hostname $worktree"
