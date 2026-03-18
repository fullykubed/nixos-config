#!/usr/bin/env bash
# Type-checks staged TypeScript files by finding their project root and running tsc --noEmit.
# Used as a pre-commit hook via git-hooks.nix.

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

info()  { echo ":: $*" >&2; }
warn()  { echo ":: Warning: $*" >&2; }

# ------------------------------------------------------------------------------
# Find project root
# ------------------------------------------------------------------------------

# Walk up from a file to find the nearest tsconfig.json, print its directory.
find_project_root() {
  local dir
  dir="$(cd "$(dirname "$1")" && pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/tsconfig.json" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

if [[ $# -eq 0 ]]; then
  exit 0
fi

# Collect unique project roots from staged files
declare -A roots
for file in "$@"; do
  root=$(find_project_root "$file") || continue
  roots["$root"]=1
done

if [[ ${#roots[@]} -eq 0 ]]; then
  exit 0
fi

failed=0
for root in "${!roots[@]}"; do
  info "Type-checking ${root##*/}..."

  # Ensure dependencies are installed
  if [[ ! -d "$root/node_modules" ]]; then
    info "Installing dependencies in ${root##*/}..."
    if ! (cd "$root" && bun install --frozen-lockfile) >&2; then
      warn "bun install failed in ${root##*/}, skipping type-check"
      failed=1
      continue
    fi
  fi

  # Run tsc --noEmit from the project root
  if ! (cd "$root" && tsc --noEmit) >&2; then
    failed=1
  fi
done

exit $failed
