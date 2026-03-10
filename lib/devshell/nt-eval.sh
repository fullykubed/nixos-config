#!/usr/bin/env bash
# mnemonic: [n]ixos [t]est - eval check
# Evaluate the full NixOS configuration to verify it resolves without errors.
# Usage: nt-eval [hostname]
# Defaults to the current machine's hostname.

info()  { echo ":: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || error "not in a git repository"
cd "$REPO_ROOT" || exit

HOST=${1:-$(hostname)}
info "Evaluating nixosConfigurations.$HOST"

nix eval --impure ".#nixosConfigurations.$HOST.config.system.build.toplevel" 2>&1 | head -80
