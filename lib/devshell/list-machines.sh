#!/usr/bin/env bash
# List all machines defined in the flake with their host key status.
# Outputs JSON to stdout for consumption by other devshell scripts.

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || { echo ":: Error: not in a git repository" >&2; exit 1; }
cd "$REPO_ROOT" || exit

mapfile -t machines < <(
  nix eval .#nixosConfigurations --apply 'x: builtins.attrNames x' --json \
    | jq -r '.[]' \
    | sort
)

jq -n --argjson count "${#machines[@]}" '
  [inputs] | to_entries | map({
    name: .value.name,
    hasHostKey: .value.hasHostKey
  })
' < <(
  for m in "${machines[@]}"; do
    has_key=false
    [[ -f "secrets/machines/${m}/ssh-host-key.age" ]] && has_key=true
    jq -n --arg name "$m" --argjson hasHostKey "$has_key" \
      '{name: $name, hasHostKey: $hasHostKey}'
  done
)
