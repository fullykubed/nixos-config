#!/usr/bin/env bash
# mnemonic: [n]ixos [t]est - full build
# Build the complete NixOS system without switching.
# Usage: nt-build [hostname]
# Defaults to the current machine's hostname.

info()  { echo ":: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || error "not in a git repository"
cd "$REPO_ROOT" || exit

HOST=${1:-$(hostname)}
LOG=$(mktemp --suffix=.nt-build.log)

info "Building full system for nixosConfigurations.$HOST"
info "Build log: $LOG"

nix build --no-link --impure ".#nixosConfigurations.$HOST.config.system.build.toplevel" > "$LOG" 2>&1
