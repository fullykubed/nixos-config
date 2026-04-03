#!/bin/sh
# Resolve a compiler name to its absolute path, skipping a given
# directory so we never resolve back to our own wrappers.
#
# Usage: resolve-unwrapped <wrap-dir> <compiler-name-or-path>
# Prints the resolved absolute path to stdout.

_wrap_dir="$1"
_val="$2"

# Already absolute — pass through.
case "$_val" in
  /*) echo "$_val"; exit 0 ;;
esac

# Walk PATH, skipping the wrapper dir.
_saved_IFS="$IFS"
IFS=:
for _p in $PATH; do
  IFS="$_saved_IFS"
  if [ "$_p" = "$_wrap_dir" ]; then continue; fi
  if [ -x "$_p/$_val" ]; then
    echo "$_p/$_val"
    exit 0
  fi
done
IFS="$_saved_IFS"

# Fallback — return as-is.
echo "$_val"
