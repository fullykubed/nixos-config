#!/bin/sh
# Cargo wrapper — interposes ccache on CC_*/CXX_*/HOST_CC/HOST_CXX.
#
# nixpkgs cargo build hooks set CC_<target>=<store-path> which the cc
# crate prefers over $CC, bypassing our ccache wrappers. This wrapper
# rewrites those vars to point at per-var ccache wrappers before
# exec-ing the real cargo.
#
# Placeholders (see default.nix cargoWrapperTemplate for substitution):
#
#   Nix eval-time (@@-wrapped, replaced by builtins.replaceStrings):
#     WRAPPER_TEMPLATE — store path to the compiler wrapper template
#
#   Build-time (%%-wrapped, replaced by sed in ccacheHook):
#     WRAP_DIR   — directory for generated wrapper scripts
#     REAL_CARGO — absolute path to the real cargo binary

_w="%WRAP_DIR%"
for _var in $(env | sed -n 's/^\(CC_[A-Za-z0-9_]*\)=.*/\1/p; s/^\(CXX_[A-Za-z0-9_]*\)=.*/\1/p') HOST_CC HOST_CXX; do
  eval "_val=\$$_var"
  if [ -z "$_val" ]; then continue; fi
  case "$_val" in "$_w"/*) continue ;; esac
  case "$_val" in /*) ;; *) continue ;; esac
  if [ ! -f "$_w/$_var" ]; then
    sed -e "s|%REAL_COMPILER%|$_val|g" \
      @WRAPPER_TEMPLATE@ > "$_w/$_var"
    chmod +x "$_w/$_var"
  fi
  export "$_var=$_w/$_var"
done
exec %REAL_CARGO% "$@"
