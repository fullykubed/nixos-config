#!/usr/bin/env bash
# PostToolUse hook: run linters on edited files
# Dispatches by file extension first, then runs only applicable tools in parallel.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jaq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Universal check: file must be git-tracked for nix flake builds to see it
# Skip files outside the repo (e.g. /tmp files Claude creates)
{
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$REPO_ROOT" && "$FILE_PATH" == "$REPO_ROOT"/* ]] &&
     ! git ls-files --error-unmatch "$FILE_PATH" &>/dev/null &&
     ! git check-ignore -q "$FILE_PATH" 2>/dev/null; then
    echo "git-untracked" >>"$TMPDIR/failed"
  fi
} &

case "$FILE_PATH" in
  */package.json)
    { bun run "$CLAUDE_PROJECT_DIR/lib/devshell/check-package-json.ts" >"$TMPDIR/check-package-json" 2>&1 || echo "check-package-json" >>"$TMPDIR/failed"; } &
    ;;
  */.claude/hooks/*.sh)
    # Meta-scripts under .claude/hooks/ contain literal references to
    # forbidden tools (jq/yq/find) inside their own grep guards. We run
    # only the static-analysis check here and skip the no-* word-match
    # checks to avoid self-tripping when the dispatcher lints itself.
    { shellcheck "$FILE_PATH" >"$TMPDIR/shellcheck" 2>&1 || echo "shellcheck" >>"$TMPDIR/failed"; } &
    ;;
  *.sh | *.bash)
    { shellcheck "$FILE_PATH" >"$TMPDIR/shellcheck" 2>&1 || echo "shellcheck" >>"$TMPDIR/failed"; } &
    { grep -nw 'jq' "$FILE_PATH" | grep -vE '^[0-9]+:[[:space:]]*#' >"$TMPDIR/no-jq" 2>&1 && echo "no-jq" >>"$TMPDIR/failed"; } &
    { grep -nw 'yq' "$FILE_PATH" | grep -vE '^[0-9]+:[[:space:]]*#' >"$TMPDIR/no-yq" 2>&1 && echo "no-yq" >>"$TMPDIR/failed"; } &
    { grep -nw 'find' "$FILE_PATH" | grep -vE '^[0-9]+:[[:space:]]*#' >"$TMPDIR/no-find" 2>&1 && echo "no-find" >>"$TMPDIR/failed"; } &
    ;;
esac

wait

if [[ ! -f "$TMPDIR/failed" ]]; then
  exit 0
fi

ERRORS=""
while read -r tool; do
  case "$tool" in
    shellcheck)
      ERRORS+="$(cat "$TMPDIR/shellcheck")"$'\n'
      ;;
    no-jq)
      ERRORS+="jq usage detected — use jaq instead:"$'\n'"$(cat "$TMPDIR/no-jq")"$'\n'
      ;;
    no-yq)
      ERRORS+="yq usage detected — use jaq instead:"$'\n'"$(cat "$TMPDIR/no-yq")"$'\n'
      ;;
    no-find)
      ERRORS+="find usage detected — use bfs instead:"$'\n'"$(cat "$TMPDIR/no-find")"$'\n'
      ;;
    check-package-json)
      ERRORS+="$(cat "$TMPDIR/check-package-json")"$'\n'
      ;;
    git-untracked)
      git add "$FILE_PATH"
      ;;
  esac
done <"$TMPDIR/failed"

if [[ -n "$ERRORS" ]]; then
  echo "$ERRORS" >&2
  exit 2
fi
