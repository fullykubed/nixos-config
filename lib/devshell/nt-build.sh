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
info "Building full system for nixosConfigurations.$HOST"

nix build --no-link --impure ".#nixosConfigurations.$HOST.config.system.build.toplevel" 2>&1
