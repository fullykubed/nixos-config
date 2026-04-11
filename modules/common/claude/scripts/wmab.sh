#!/usr/bin/env bash
# wmab: workmux add with auto branch name
# Usage: wmab <prompt text>
set -euo pipefail

prompt="$*"

repo_branches=$(git branch -a --sort=-committerdate 2>/dev/null \
  | head -10 \
  | sed 's/^[* ]*//' \
  | sed 's|remotes/origin/||' \
  | grep -v '^HEAD' \
  | tr '\n' ', ' \
  | sed 's/, $//')

branch_name=$(claude -p \
  --model haiku \
  --tools "" \
  --no-session-persistence \
  --output-format json \
  --json-schema '{"type":"object","properties":{"branch":{"type":"string","pattern":"^[a-z0-9][a-z0-9/-]*[a-z0-9]$"}},"required":["branch"],"additionalProperties":false}' \
  --system-prompt "Generate a concise git branch name. Rules: kebab-case (lowercase with hyphens), 2-4 words max, focus on core task or feature not implementation details. By default avoid prefixes like feat/ or fix/, but if the repository examples use that pattern, follow it. Repository branch examples: $repo_branches" \
  "$prompt" | @jaq@ -r '.structured_output.branch')

exec workmux add -b -p "$prompt" "$branch_name"
