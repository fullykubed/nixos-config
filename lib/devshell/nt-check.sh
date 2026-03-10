#!/usr/bin/env bash
# mnemonic: [n]ixos [t]est - flake checks
# Run nix flake check (pre-commit hooks, linters, any registered checks).
# Usage: nt-check

info()  { echo ":: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || error "not in a git repository"
cd "$REPO_ROOT" || exit

info "Running flake checks"
nix flake check --impure 2>&1
