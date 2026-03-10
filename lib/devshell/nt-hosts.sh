#!/usr/bin/env bash
# mnemonic: [n]ixos [t]est - list available hostnames
# Lists nixosConfigurations defined in the flake and marks the current host.
# Usage: nt-hosts

info()  { echo ":: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || error "not in a git repository"
cd "$REPO_ROOT" || exit

CURRENT=$(hostname)

info "Available nixosConfigurations:"
for host in $(nix eval --impure --raw --apply 'x: builtins.concatStringsSep "\n" (builtins.attrNames x)' .#nixosConfigurations 2>/dev/null); do
  if [[ "$host" == "$CURRENT" ]]; then
    echo "  $host  (current)"
  else
    echo "  $host"
  fi
done
