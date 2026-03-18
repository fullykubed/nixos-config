#!/usr/bin/env bash
# Runs ESLint on staged TypeScript files.
# Used as a pre-commit hook via git-hooks.nix.

info()  { echo ":: $*" >&2; }
warn()  { echo ":: Warning: $*" >&2; }

if [[ $# -eq 0 ]]; then
  exit 0
fi

# Find repo root (where eslint.config.ts lives)
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Ensure ESLint dependencies are installed
if [[ ! -d "$REPO_ROOT/node_modules" ]]; then
  info "Installing ESLint dependencies..."
  if ! (cd "$REPO_ROOT" && bun install --frozen-lockfile) >&2; then
    warn "bun install failed at repo root, skipping ESLint"
    exit 1
  fi
fi

info "Linting staged TypeScript files..."
(cd "$REPO_ROOT" && bunx eslint --no-warn-ignored "$@") >&2 || exit 1
