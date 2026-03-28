# Custom stdenv with additional hardening flags, mold linker, and ccache
#
# This module overrides the default stdenv to:
# 1. Enable additional hardening flags globally (trivialautovarinit)
# 2. Use the mold linker for all compatible packages (faster than GNU ld)
# 3. Use ccache as a C/C++ compiler wrapper for all compatible packages
# 4. Disable reference checks to allow CVE patches on bootstrap packages
# 5. Exclude specific packages from aggressive hardening
#
# Mold and ccache are built from a clean nixpkgs import (no overlays) to
# avoid a circular dependency (they need stdenv, our stdenv adds them).
#
# Per-package test/build overrides caused by the custom stdenv live in modules/patches/.
{
  lib,
  system,
  nixpkgs-unstable-input,
  ...
}:
let
  # Import a clean nixpkgs (no overlays) for packages that our stdenv
  # adds globally. Without this, they'd be built with our custom stdenv,
  # creating a circular dependency.
  cleanPkgs = import nixpkgs-unstable-input {
    inherit system;
    config.allowUnfree = true;
  };
  cleanMold = cleanPkgs.mold;
  cleanCcache = cleanPkgs.ccache;

  # The mold flag fragments.
  moldCFragment = " -fuse-ld=mold";
  moldRustFragment = " -C link-arg=-fuse-ld=mold";

  # The ccache preConfigure hook, defined once at module level.
  ccacheHook = ''

    if [ -f "''${CCACHE_DIR:-}/.disabled" ]; then
      echo "ccache: disabled via .disabled sentinel"
    elif [ ! -d "''${CCACHE_DIR:-}" ]; then
      echo "====="
      echo "ccache: directory '$CCACHE_DIR' does not exist"
      echo "====="
    elif [ ! -w "''${CCACHE_DIR:-}" ]; then
      echo "====="
      echo "ccache: directory '$CCACHE_DIR' is not writable"
      echo "Please verify it is owned by root:nixbld with mode 0770"
      echo "====="
    elif [[ "''${CC:-}" == */build/.ccache-wrap/* ]] || [[ "''${CXX:-}" == */build/.ccache-wrap/* ]]; then
      : # CC/CXX already point to ccache wrapper; skip to avoid infinite recursion
    else
      _ccache_wrap=/build/.ccache-wrap
      mkdir -p "$_ccache_wrap"
      _orig_cc="''${CC:-cc}"
      _orig_cxx="''${CXX:-c++}"
      _cc_name="$(basename "''${_orig_cc%% *}")"
      _cxx_name="$(basename "''${_orig_cxx%% *}")"
      _ccache_bin="$(command -v ccache)"
      _mkwrapper() {
        printf '#!/bin/sh\nfor _a in "$@"; do\n  if [ "$_a" = "-c" ]; then\n    exec %s %s "$@"\n  fi\ndone\nexec %s "$@"\n' "$_ccache_bin" "$2" "$2" > "$1"
        chmod +x "$1"
      }
      _mkwrapper "$_ccache_wrap/$_cc_name" "$_orig_cc"
      _mkwrapper "$_ccache_wrap/$_cxx_name" "$_orig_cxx"
      export CC="$_ccache_wrap/$_cc_name"
      export CXX="$_ccache_wrap/$_cxx_name"

      # Haskell: setupCompilerEnvironmentPhase (a prePhase) bakes $CC into
      # configureFlags as --with-gcc=<path> before preConfigure runs.  Patch
      # the already-resolved path so GHC uses the ccache wrapper too.
      if [[ "''${configureFlags:-}" == *--with-gcc=* ]]; then
        configureFlags="$(echo "$configureFlags" | sed "s|--with-gcc=[^ ]*|--with-gcc=$CC|g")"
      fi
    fi
  '';

  stdenvOverlay =
    _final: prev:
    let
      # =========================================================================
      # Additional hardening flags
      # =========================================================================
      #
      # Available flags:
      #   - trivialautovarinit: Zero-init automatic variables (-ftrivial-auto-var-init=pattern)
      #   - glibcxxassertions: libstdc++ runtime assertions (-D_GLIBCXX_ASSERTIONS)
      #   - nostrictaliasing: Disable strict aliasing (-fno-strict-aliasing)
      #   - strictflexarrays3: Strict flexible array bounds (-fstrict-flex-arrays=3)
      #   - libcxxhardeningextensive: libc++ hardening (-D_LIBCPP_HARDENING_MODE=...)
      #   - shadowstack: Intel CET shadow stack (-fcf-protection=return)
      #
      hardeningFlags = [
        "trivialautovarinit"
        # "glibcxxassertions"
        # "nostrictaliasing"
        # "strictflexarrays3"
        # "libcxxhardeningextensive"
        # "shadowstack"
      ];

      # =========================================================================
      # mkDerivation wrapper
      # =========================================================================

      # Compilers, assemblers, and test frameworks excluded from our extra
      # hardening flags. They still get default nixpkgs hardening.
      hardeningExcludedNames = [
        "gcc"
        "gfortran"
        "clang"
        "llvm"
        "ldc"
        "dmd"
        "fpc"
        "binutils"
        "nasm"
        "yasm"
        "dejagnu"
      ];

      # Packages excluded from ccache by pname.
      ccacheExcludedNames = [
        "ghc-binary" # bakes CC path into settings file; downstream Haskell packages need a real store path
        "kexec-tools" # cached .d dependency files contain stale store paths; make install re-reads them and fails
        "metis" # two-phase cmake configure loses install prefix when ccache changes CMAKE_C_COMPILER
        "sbsigntool" # ccan Makefile re-reads .d files with stale glibc-dev paths; same class as kexec-tools
        "shiboken6" # bakes compiler path into installed config; ccache wrapper path breaks downstream pyside6
      ];

      # Packages excluded from mold by pname.
      moldExcludedNames = [
        "elfutils" # installcheck self-tests expect GNU ld ELF section layout
        "linux-pam" # version script lists optional symbols mold rejects as missing
        "glib" # mold breaks girepository build
        "nss" # shared version script has symbols absent from individual .so files
        "zlib" # bootstrap package; mold causes circular dependency in early stages
        "monero-gui" # mold misparses Qt5 rpath entries, concatenating .so paths as directories
        "firefox-unwrapped" # elfhack passes --real-linker to ld.lld; mold doesn't support it
      ];

      addFlags =
        _stdenv: args:
        let
          additions =
            a:
            let
              useHardening = !(a ? pname && builtins.elem a.pname hardeningExcludedNames);

              # Detect bootstrap stdenvs via the stdenv's .name string attribute
              # (not .cc or other derivation attrs, which would cause infinite recursion).
              isBootstrap = prev.lib.hasPrefix "bootstrap-" (_stdenv.name or "");
              useMold = !isBootstrap && !(a ? pname && builtins.elem a.pname moldExcludedNames);
              useCcache = !isBootstrap && !(a ? pname && builtins.elem a.pname ccacheExcludedNames);

              # Build env incrementally. Mold flags go into env.* unless the
              # derivation sets NIX_CFLAGS_LINK / RUSTFLAGS as top-level attrs,
              # in which case we append there to preserve the derivation's convention.
              baseEnv = a.env or { };
              env =
                baseEnv
                // (prev.lib.optionalAttrs (useMold && !(a ? NIX_CFLAGS_LINK)) {
                  NIX_CFLAGS_LINK = toString (baseEnv.NIX_CFLAGS_LINK or "") + moldCFragment;
                })
                // (prev.lib.optionalAttrs (useMold && !(a ? RUSTFLAGS)) {
                  RUSTFLAGS = toString (baseEnv.RUSTFLAGS or "") + moldRustFragment;
                })
                // (prev.lib.optionalAttrs useCcache {
                  CCACHE_DIR = "/var/cache/ccache";
                });

            in
            {
              doCheck = false;
              inherit env;
              hardeningEnable =
                if useHardening then
                  prev.lib.unique ((a.hardeningEnable or [ ]) ++ hardeningFlags)
                else
                  (a.hardeningEnable or [ ]);
              nativeBuildInputs =
                (a.nativeBuildInputs or [ ])
                ++ prev.lib.optionals useMold [ cleanMold ]
                ++ prev.lib.optionals useCcache [ cleanCcache ];
            }
            // (prev.lib.optionalAttrs (useMold && a ? NIX_CFLAGS_LINK) {
              NIX_CFLAGS_LINK = toString a.NIX_CFLAGS_LINK + moldCFragment;
            })
            // (prev.lib.optionalAttrs (useMold && a ? RUSTFLAGS) {
              RUSTFLAGS = toString a.RUSTFLAGS + moldRustFragment;
            })
            # Attribute NAME must not depend on a.preConfigure (a value from
            # originalAttrs).  In the make-derivation.nix fixpoint, attribute
            # names of the additions attrset are needed to resolve the `//`
            # merge, which would force evaluation of finalAttrs and recurse.
            # Gate on `useCcache` (depends only on pname / isBootstrap) so the
            # name is always present when ccache is active; the VALUE is lazy.
            // (prev.lib.optionalAttrs useCcache {
              preConfigure =
                let
                  existing = a.preConfigure or null;
                in
                if existing == null then
                  ccacheHook
                else if builtins.isString existing then
                  existing + ccacheHook
                else
                  existing;
            });
        in
        if builtins.isFunction args then
          finalAttrs:
          let
            originalAttrs = args finalAttrs;
          in
          originalAttrs // additions originalAttrs
        else
          args // additions args;

      baseMkDerivationFromStdenv = import "${prev.path}/pkgs/stdenv/generic/make-derivation.nix" {
        inherit (prev) lib config;
      };

    in
    {
      stdenv = prev.stdenv.override {
        allowedRequisites = null;
        disallowedRequisites = null;
        mkDerivationFromStdenv =
          stdenv: args: (baseMkDerivationFromStdenv stdenv).mkDerivation (addFlags stdenv args);
      };
    };
in
{
  nixpkgs.overlays = lib.mkBefore [ stdenvOverlay ];
  nixpkgs-unstable.overlays = lib.mkBefore [ stdenvOverlay ];
}
