#!/usr/bin/env bash
# Reads a surprise file by slug and outputs its full content
# Usage: claude-Surprises-get <slug>

set -euo pipefail

if [[ $# -lt 1 ]] || [[ -z "$1" ]]; then
    echo "Usage: claude-Surprises-get <slug>" >&2
    exit 1
fi

SLUG="$1"

MAIN_WORKTREE=$(git-default-worktree-path)

SURPRISES_DIR="${MAIN_WORKTREE}/.claude/surprises"
SURPRISE_FILE="${SURPRISES_DIR}/${SLUG}.md"

if [[ ! -f "$SURPRISE_FILE" ]]; then
    echo "Error: surprise '${SLUG}' not found in ${SURPRISES_DIR}" >&2
    exit 1
fi

cat "$SURPRISE_FILE"
