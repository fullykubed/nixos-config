#!/usr/bin/env bash
# mnemonic: [n]ixos [t]est - syntax check
# Parse .nix files for syntax errors without evaluating anything.
# Usage: nt-syntax [file ...]
# If no files given, checks all .nix files changed since HEAD.

info()  { echo ":: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || error "not in a git repository"
cd "$REPO_ROOT" || exit

files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
  mapfile -t files < <(git diff --name-only HEAD -- '*.nix')
fi

if [[ ${#files[@]} -eq 0 ]]; then
  info "No .nix files to check"
  exit 0
fi

failed=0
for f in "${files[@]}"; do
  if nix-instantiate --parse "$f" > /dev/null 2>&1; then
    info "OK  $f"
  else
    info "FAIL $f"
    nix-instantiate --parse "$f" 2>&1 | head -20 >&2
    failed=$((failed + 1))
  fi
done

if [[ $failed -gt 0 ]]; then
  error "$failed file(s) failed syntax check"
fi
info "All ${#files[@]} file(s) passed"
