#!/usr/bin/env bash
# Checks that shared dependencies across package.json files use consistent versions.
# Used as a pre-commit hook via git-hooks.nix.

mapfile -t files < <(find . -name 'package.json' -not -path '*/node_modules/*' | sort)

if [[ ${#files[@]} -lt 2 ]]; then
  exit 0
fi

# Extract all deps as "pkg_name\tfile\tversion" lines
all_deps=""
for file in "${files[@]}"; do
  file_deps=$(jaq -r '
    [(.dependencies // {}), (.devDependencies // {})] | add // {} |
    to_entries[] | "\(.key)\t\(.value)"
  ' "$file") || continue

  while IFS=$'\t' read -r name version; do
    [[ -z "$name" ]] && continue
    all_deps+="${name}"$'\t'"${file}"$'\t'"${version}"$'\n'
  done <<< "$file_deps"
done

# Find version mismatches using awk
conflicts=$(printf '%s' "$all_deps" | awk -F'\t' '
  $1 != "" {
    pkg = $1; file = $2; ver = $3
    if (pkg in versions) {
      if (versions[pkg] != ver) {
        if (!(pkg in printed)) {
          printf "Version mismatch for %s:\n", pkg
          printf "  %s: %s\n", first_file[pkg], versions[pkg]
          printed[pkg] = 1
        }
        printf "  %s: %s\n", file, ver
      }
    } else {
      versions[pkg] = ver
      first_file[pkg] = file
    }
  }
')

if [[ -n "$conflicts" ]]; then
  echo "$conflicts"
  exit 1
fi
