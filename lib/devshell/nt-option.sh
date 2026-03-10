#!/usr/bin/env bash
# mnemonic: [n]ixos [t]est - build/eval config option
# Build or evaluate a specific NixOS config option.
# Usage: nt-option <option-path> [hostname]
#   option-path: dot-separated config path (e.g. config.boot.kernelPackages.kernel)
#   hostname: defaults to current machine
# Tries nix build first; falls back to nix eval for non-derivation values.

info()  { echo ":: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || error "not in a git repository"
cd "$REPO_ROOT" || exit

OPTION=${1:-""}
HOST=${2:-$(hostname)}

[[ -z "$OPTION" ]] && error "Usage: nt-option <option-path> [hostname]"

ATTR=".#nixosConfigurations.$HOST.$OPTION"
info "Testing $ATTR"

if nix build "$ATTR" --no-link 2>&1; then
  info "Build succeeded"
else
  info "Not a buildable derivation, trying eval..."
  nix eval --impure "$ATTR" 2>&1 | head -40
fi
