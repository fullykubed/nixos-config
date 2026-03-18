{ pkgs }:
pkgs.writeShellScriptBin "extract-frontmatter" ''
  set -euo pipefail

  if [[ $# -lt 1 ]]; then
    echo "Usage: extract-frontmatter <file.md>" >&2
    exit 1
  fi

  if [[ ! -r "$1" ]]; then
    echo "extract-frontmatter: cannot read file: $1" >&2
    exit 1
  fi

  ${pkgs.gawk}/bin/awk '
    /^---$/ { if (found == 0) { found=1; next } else { exit } }
    found { print }
  ' "$1"
''
