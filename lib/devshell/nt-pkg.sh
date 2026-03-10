#!/usr/bin/env bash
# mnemonic: [n]ixos [t]est - build package
# Build a single package from the per-host package set.
# Usage: nt-pkg <package> [channel] [hostname]
#   channel: stable (default) or unstable
#   hostname: defaults to current machine

info()  { echo ":: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || error "not in a git repository"
cd "$REPO_ROOT" || exit

PKG=${1:-""}
CHANNEL=${2:-stable}
HOST=${3:-$(hostname)}

[[ -z "$PKG" ]] && error "Usage: nt-pkg <package> [stable|unstable] [hostname]"

info "Building $HOST.$CHANNEL.$PKG"
nix build ".#$HOST.$CHANNEL.$PKG" --no-link 2>&1
