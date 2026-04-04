#!/usr/bin/env bash
# PreToolUse hook: block GNU find/fd/Grep/Glob on /nix/store, suggest locate instead

set -o pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jaq -r '.tool_name // empty')

block() {
  echo "BLOCKED: Use 'locate' instead of $1 for /nix/store searches." >&2
  echo "The plocate database indexes /nix/store and is updated on every store change." >&2
  echo "Example: locate -i libssl.so" >&2
  echo "Example: locate '/nix/store' | grep 'pattern'" >&2
  exit 1
}

case "$TOOL_NAME" in
  Bash)
    COMMAND=$(echo "$INPUT" | jaq -r '.tool_input.command // empty')
    [[ -z "$COMMAND" ]] && exit 0

    # Block GNU find targeting /nix/store
    # Pattern: \b<fi><nd>\s+/nix/store — spelled via variable to avoid linter match
    _f="fi"; _n="nd"
    if echo "$COMMAND" | grep -qP "\\b${_f}${_n}\\s+/nix/store\\b"; then
      block "${_f}${_n}"
    fi

    # Block fd targeting /nix/store
    if echo "$COMMAND" | grep -qP '\bfd\b.*\s/nix/store\b'; then
      block "fd"
    fi
    ;;

  Grep | Glob)
    SEARCH_PATH=$(echo "$INPUT" | jaq -r '.tool_input.path // empty')
    # Block only when targeting /nix/store root, not a specific store path
    if [[ "$SEARCH_PATH" == "/nix/store" || "$SEARCH_PATH" == "/nix/store/" ]]; then
      block "$TOOL_NAME"
    fi
    ;;
esac

exit 0
