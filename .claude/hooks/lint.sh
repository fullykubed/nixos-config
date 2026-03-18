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

case "$FILE_PATH" in
  *.nix)
    { nixfmt --check "$FILE_PATH" >"$TMPDIR/nixfmt" 2>&1 || echo "nixfmt" >>"$TMPDIR/failed"; } &
    { statix check "$FILE_PATH" >"$TMPDIR/statix" 2>&1 || echo "statix" >>"$TMPDIR/failed"; } &
    { deadnix --fail "$FILE_PATH" >"$TMPDIR/deadnix" 2>&1 || echo "deadnix" >>"$TMPDIR/failed"; } &
    { gitleaks dir --config "$CLAUDE_PROJECT_DIR/gitleaks.toml" --no-banner "$FILE_PATH" >"$TMPDIR/gitleaks" 2>&1 || echo "gitleaks" >>"$TMPDIR/failed"; } &
    ;;
  */package.json)
    { "$CLAUDE_PROJECT_DIR/lib/devshell/check-bun-versions.sh" >"$TMPDIR/check-bun-versions" 2>&1 || echo "check-bun-versions" >>"$TMPDIR/failed"; } &
    { gitleaks dir --config "$CLAUDE_PROJECT_DIR/gitleaks.toml" --no-banner "$FILE_PATH" >"$TMPDIR/gitleaks" 2>&1 || echo "gitleaks" >>"$TMPDIR/failed"; } &
    ;;
  *.sh | *.bash)
    { shellcheck "$FILE_PATH" >"$TMPDIR/shellcheck" 2>&1 || echo "shellcheck" >>"$TMPDIR/failed"; } &
    { grep -nw 'jq' "$FILE_PATH" | grep -vE '^[0-9]+:[[:space:]]*#' >"$TMPDIR/no-jq" 2>&1 && echo "no-jq" >>"$TMPDIR/failed"; } &
    { grep -nw 'yq' "$FILE_PATH" | grep -vE '^[0-9]+:[[:space:]]*#' >"$TMPDIR/no-yq" 2>&1 && echo "no-yq" >>"$TMPDIR/failed"; } &
    { grep -nw 'find' "$FILE_PATH" | grep -vE '^[0-9]+:[[:space:]]*#' >"$TMPDIR/no-find" 2>&1 && echo "no-find" >>"$TMPDIR/failed"; } &
    { gitleaks dir --config "$CLAUDE_PROJECT_DIR/gitleaks.toml" --no-banner "$FILE_PATH" >"$TMPDIR/gitleaks" 2>&1 || echo "gitleaks" >>"$TMPDIR/failed"; } &
    ;;
  *)
    { gitleaks dir --config "$CLAUDE_PROJECT_DIR/gitleaks.toml" --no-banner "$FILE_PATH" >"$TMPDIR/gitleaks" 2>&1 || echo "gitleaks" >>"$TMPDIR/failed"; } &
    ;;
esac

wait

if [[ ! -f "$TMPDIR/failed" ]]; then
  exit 0
fi

ERRORS=""
while read -r tool; do
  case "$tool" in
    nixfmt)
      nixfmt "$FILE_PATH" 2>/dev/null
      ERRORS+="nixfmt: file was not formatted correctly and has been auto-formatted: $FILE_PATH"$'\n'
      ;;
    statix)
      ERRORS+="$(cat "$TMPDIR/statix")"$'\n'
      ;;
    deadnix)
      ERRORS+="$(cat "$TMPDIR/deadnix")"$'\n'
      ;;
    gitleaks)
      ERRORS+="$(cat "$TMPDIR/gitleaks")"$'\n'
      ;;
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
    check-bun-versions)
      ERRORS+="$(cat "$TMPDIR/check-bun-versions")"$'\n'
      ;;
  esac
done <"$TMPDIR/failed"

echo "$ERRORS" >&2
exit 2
