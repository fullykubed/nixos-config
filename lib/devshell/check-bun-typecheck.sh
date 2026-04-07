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
# Offline bun install helper
#
# When BUN_DEPS_CACHE_DIR is set (by the Nix-built hook wrapper), copy the
# pre-fetched bun cache into a writable temp directory and point
# BUN_INSTALL_CACHE_DIR at it so `bun install` can run without network access.
# This is the same pattern the bun2nix setup hook uses in Nix derivation builds.
# ------------------------------------------------------------------------------

setup_offline_bun_cache() {
  if [[ -n "${BUN_DEPS_CACHE_DIR:-}" ]]; then
    local writable_cache
    writable_cache=$(mktemp -d)
    # Use -L to dereference symlinks: the merged-bun-cache is a symlinkJoin of
    # per-package store paths, so a plain `cp -r` would copy the symlinks
    # themselves rather than the files they point to.  Bun then tries to update
    # metadata in those symlinked (read-only Nix store) paths and gets
    # AccessDenied.  Dereferencing upfront gives bun a fully-writable copy.
    cp -rL "${BUN_DEPS_CACHE_DIR}/." "$writable_cache"
    # Make cache files writable so bun can update metadata.
    chmod -R u+rw "$writable_cache"
    export BUN_INSTALL_CACHE_DIR="$writable_cache"
  fi
  # Always use --frozen-lockfile: keeps the install reproducible and lets bun
  # resolve exact versions from the lockfile without hitting the registry.
  BUN_INSTALL_FLAGS="--frozen-lockfile"
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

if [[ $# -eq 0 ]]; then
  exit 0
fi

setup_offline_bun_cache

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
    # shellcheck disable=SC2086
    if ! (cd "$root" && bun install ${BUN_INSTALL_FLAGS}) >&2; then
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
