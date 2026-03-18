#!/usr/bin/env bash
# Type-checks a single TypeScript file by finding its project root and running tsc --noEmit.
# Called from the PostToolUse lint hook. Reads the file path from $1.

FILE_PATH="$1"

if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Walk up from the file to find the nearest tsconfig.json
dir=$(cd "$(dirname "$FILE_PATH")" && pwd)
while [[ "$dir" != "/" ]]; do
  if [[ -f "$dir/tsconfig.json" ]]; then
    break
  fi
  dir=$(dirname "$dir")
done

if [[ ! -f "$dir/tsconfig.json" ]]; then
  exit 0
fi

# Ensure dependencies are installed
if [[ ! -d "$dir/node_modules" ]]; then
  (cd "$dir" && bun install --frozen-lockfile) >&2 || exit 1
fi

(cd "$dir" && bunx tsc --noEmit) 2>&1 || exit 1
