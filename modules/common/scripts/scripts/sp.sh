#!/usr/bin/env bash

set -o pipefail

# mnemonic: [S]earch $[P]ATH
# Fuzzy searches PATH for a given file name and shows the location (including the location by following all links)

SEARCH_STRING=$1

# Prints out unique entries for all the files on the path
# Note: Ignores the *.real files produced by nixos wrappers
print_files(){
  echo "$PATH" | sed -e $'s/:/\\\n/g' | xargs rg -L --files -g '!*.real' 2> /dev/null | uniq
}

# Fuzzy search the files in the path to find the query
RESULT_PATH=$(print_files | fzf -q "$SEARCH_STRING" )

# Find the location for NIXOS wrapper files
LINK=$(readlink -m "$RESULT_PATH")

# Only show the link if it exists
if [[ -z "$LINK" ]]; then
  echo "$RESULT_PATH"
else
  echo "$RESULT_PATH => $LINK"
fi

