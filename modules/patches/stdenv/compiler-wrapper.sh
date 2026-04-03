#!/bin/sh
# shellcheck shell=bash disable=SC2157,SC2194
# Compiler wrapper template (ccache + clang flag fixups).
#
# Placeholders (see default.nix wrapperTemplate for substitution):
#
#   Nix eval-time (@@-wrapped, replaced by builtins.replaceStrings):
#     CPU_ARCH       — -march value (e.g. x86-64-v3), empty if unset
#     CPU_TUNE       — -mtune value (e.g. znver4), empty if unset
#     CCACHE_BIN     — absolute store path to ccache binary
#     GCC_FLAG_STRIP — bash lines stripping each GCC-only flag (from gccOnlyFlags)
#
#   Build-time (%%-wrapped, replaced by sed in _mkwrapper):
#     REAL_COMPILER  — absolute path to the wrapped compiler
#
# When wrapping clang/clang++:
#   1. Always strips GCC-specific optimization flags (invalid for clang)
#   2. Strips -march/-mtune when targeting non-x86 (e.g. BPF)

# Bare name (not absolute) — exec directly without ccache to
# avoid an infinite loop through PATH.
case "%REAL_COMPILER%" in
  /*) ;;
  *)  exec %REAL_COMPILER% "$@" ;;
esac

_bn="$(basename "$0")"
case "$_bn" in
  clang|clang++|*-clang|*-clang++) _is_clang=true ;;
  *) _is_clang=false ;;
esac
if $_is_clang; then
  # GCC-only optimization flags — always invalid for clang.
@GCC_FLAG_STRIP@
  # Strip -march/-mtune when targeting non-x86 (e.g. clang -target bpf,
  # or cross compilers like wasm32-unknown-wasi-clang).
  # These flags are valid for clang on x86 but invalid for other targets.
  if [ -n "@CPU_ARCH@" ] || [ -n "@CPU_TUNE@" ]; then
    _strip_arch=false
    # Check for non-x86 target embedded in the binary name (cross compilers).
    case "$_bn" in
      x86*|i?86*|clang|clang++) ;;
      *-clang|*-clang++) _strip_arch=true ;;
    esac
    # Also check -target/--target arguments.
    if ! $_strip_arch; then
      _p=""
      for _a in "$@"; do
        case "$_p" in
          -target|--target)
            case "$_a" in x86*|i?86*) ;; *) _strip_arch=true ;; esac
            break
            ;;
        esac
        case "$_a" in
          --target=*)
            _t="${_a#*=}"
            case "$_t" in x86*|i?86*) ;; *) _strip_arch=true ;; esac
            break
            ;;
        esac
        _p="$_a"
      done
    fi
    if $_strip_arch; then
      if [ -n "@CPU_ARCH@" ]; then
        NIX_CFLAGS_COMPILE="${NIX_CFLAGS_COMPILE// -march=@CPU_ARCH@/}"
      fi
      if [ -n "@CPU_TUNE@" ]; then
        NIX_CFLAGS_COMPILE="${NIX_CFLAGS_COMPILE// -mtune=@CPU_TUNE@/}"
      fi
    fi
  fi

  export NIX_CFLAGS_COMPILE
fi

# Only route through ccache for compilation (-c flag present).
for _a in "$@"; do
  if [ "$_a" = "-c" ]; then
    exec @CCACHE_BIN@ %REAL_COMPILER% "$@"
  fi
done
exec %REAL_COMPILER% "$@"
