#!/usr/bin/env bash
# PostToolUse hook: run linters on edited files
# Dispatches by file extension first, then runs only applicable tools in parallel.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

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
  *.sh | *.bash)
    { shellcheck "$FILE_PATH" >"$TMPDIR/shellcheck" 2>&1 || echo "shellcheck" >>"$TMPDIR/failed"; } &
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
  esac
done <"$TMPDIR/failed"

echo "$ERRORS" >&2
exit 2
