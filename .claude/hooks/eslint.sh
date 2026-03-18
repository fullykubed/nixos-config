#!/usr/bin/env bash
# Runs ESLint on a single TypeScript file from the repo root.
# Called from the PostToolUse lint hook. Takes file path as $1.

FILE_PATH="$1"

if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"

if [[ ! -d "$REPO_ROOT/node_modules" ]]; then
  (cd "$REPO_ROOT" && bun install --frozen-lockfile) >&2 || exit 1
fi

(cd "$REPO_ROOT" && bunx eslint --no-warn-ignored "$FILE_PATH") 2>&1 || exit 1
