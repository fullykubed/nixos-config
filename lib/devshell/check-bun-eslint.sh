#!/usr/bin/env bash
# Runs ESLint on staged TypeScript files.
# Used as a pre-commit hook via git-hooks.nix.

info()  { echo ":: $*" >&2; }
warn()  { echo ":: Warning: $*" >&2; }

if [[ $# -eq 0 ]]; then
  exit 0
fi

# When BUN_DEPS_CACHE_DIR is set (by the Nix-built hook wrapper), copy the
# pre-fetched bun cache into a writable temp directory and point
# BUN_INSTALL_CACHE_DIR at it so `bun install` can run without network access.
if [[ -n "${BUN_DEPS_CACHE_DIR:-}" ]]; then
  _writable_cache=$(mktemp -d)
  # Use -L to dereference symlinks: the merged-bun-cache is a symlinkJoin of
  # per-package store paths, so a plain `cp -r` would copy the symlinks
  # themselves rather than the files they point to.  Bun then tries to update
  # metadata in those symlinked (read-only Nix store) paths and gets
  # AccessDenied.  Dereferencing upfront gives bun a fully-writable copy.
  cp -rL "${BUN_DEPS_CACHE_DIR}/." "$_writable_cache"
  # Make cache files writable so bun can update metadata.
  chmod -R u+rw "$_writable_cache"
  export BUN_INSTALL_CACHE_DIR="$_writable_cache"
fi
# Always use --frozen-lockfile so the install is reproducible and bun resolves
# exact versions from the lockfile without hitting the registry.
_bun_install_flags="--frozen-lockfile"

# Find repo root (where eslint.config.ts lives)
REPO_ROOT="$(git rev-parse --show-toplevel)"

# ESLint's projectService needs per-project node_modules to resolve types
# (e.g. bun-types for projects that use Bun built-ins). Walk up from each
# staged file to find the nearest tsconfig.json / package.json and install
# deps there if needed.  Mirrors what check-bun-typecheck does for tsc.
# Note: per-project installs run BEFORE the root install so that if a
# sub-project install somehow disturbs node_modules state, the root install
# that follows is guaranteed to be the last write before ESLint runs.
find_project_root() {
  local dir
  dir="$(cd "$(dirname "$1")" && pwd)"
  while [[ "$dir" != "/" && "$dir" != "$REPO_ROOT" ]]; do
    if [[ -f "$dir/tsconfig.json" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

declare -A project_roots
for file in "$@"; do
  root=$(find_project_root "$file") || continue
  project_roots["$root"]=1
done

for root in "${!project_roots[@]}"; do
  if [[ ! -d "$root/node_modules" ]]; then
    info "Installing dependencies in ${root##*/}..."
    # shellcheck disable=SC2086
    if ! (cd "$root" && bun install ${_bun_install_flags}) >&2; then
      warn "bun install failed in ${root##*/}, type resolution may be incomplete"
    fi
  fi
done

# Ensure ESLint dependencies are installed at repo root.
# This check runs after per-project installs so it can repair any root
# node_modules disruption caused by sub-project bun installs.
if [[ ! -f "$REPO_ROOT/node_modules/.bin/eslint" ]]; then
  info "Installing ESLint dependencies..."
  # shellcheck disable=SC2086
  if ! (cd "$REPO_ROOT" && bun install ${_bun_install_flags}) >&2; then
    warn "bun install failed at repo root, skipping ESLint"
    exit 1
  fi
fi

info "Linting staged TypeScript files..."
# Invoke ESLint via the local node_modules binary rather than `bunx` to avoid
# bun's auto-install behaviour.  After the per-project bun installs above,
# `bunx` detects the cache as stale and tries to re-install the repo root
# deps, which fails in the Nix sandbox because the cache is partially consumed.
# Using the pre-installed binary directly sidesteps this.
(cd "$REPO_ROOT" && ./node_modules/.bin/eslint --no-warn-ignored "$@") >&2 || exit 1
