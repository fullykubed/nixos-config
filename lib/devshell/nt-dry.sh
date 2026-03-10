#!/usr/bin/env bash
# mnemonic: [n]ixos [t]est - dry build
# Show what would be built without building anything.
# Usage: nt-dry [hostname]
# Defaults to the current machine's hostname.

info()  { echo ":: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || error "not in a git repository"
cd "$REPO_ROOT" || exit

HOST=${1:-$(hostname)}
info "Dry-building nixosConfigurations.$HOST"

nix build --dry-run --impure ".#nixosConfigurations.$HOST.config.system.build.toplevel" 2>&1
