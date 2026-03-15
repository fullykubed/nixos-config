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
# Packages can opt out of mold by setting __noMold = true via overrideAttrs.
# Packages can opt out of ccache by setting __noCcache = true via overrideAttrs.
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
        "metis" # two-phase cmake configure loses install prefix when ccache changes CMAKE_C_COMPILER
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

              # Detect bootstrap stdenvs by checking the stdenv's .name attribute.
              # We use _stdenv.name (a plain string) rather than _stdenv.cc or other
              # derivation attributes because those would force evaluation of packages
              # built with this same mkDerivation, causing infinite recursion through
              # the fixed-point. String attributes are set during stdenv construction
              # and don't trigger any derivation evaluation.
              isBootstrap = prev.lib.hasPrefix "bootstrap-" (_stdenv.name or "");
              useMold =
                !isBootstrap && !(a.__noMold or false) && !(a ? pname && builtins.elem a.pname moldExcludedNames);

              useCcache =
                !isBootstrap
                && !(a.__noCcache or false)
                && !(a ? pname && builtins.elem a.pname ccacheExcludedNames);

              # Mold linker flags are injected into whichever location the
              # derivation already uses. If the derivation sets NIX_CFLAGS_LINK
              # or RUSTFLAGS as top-level attributes, we append there to
              # preserve the derivation's convention. Otherwise we inject via
              # env.* — the modern nixpkgs convention that avoids polluting the
              # derivation's attribute namespace.
              cMoldFlags =
                if !useMold then
                  { }
                else if a ? NIX_CFLAGS_LINK then
                  { NIX_CFLAGS_LINK = toString a.NIX_CFLAGS_LINK + " -fuse-ld=mold"; }
                else
                  {
                    env = (a.env or { }) // {
                      NIX_CFLAGS_LINK = toString ((a.env or { }).NIX_CFLAGS_LINK or "") + " -fuse-ld=mold";
                    };
                  };

              # When both C and Rust flags land in env, rustMoldFlags must
              # chain cMoldFlags.env so the final // merge doesn't clobber
              # the C linker flags with a fresh env attrset.
              rustMoldFlags =
                if !useMold then
                  { }
                else if a ? RUSTFLAGS then
                  { RUSTFLAGS = toString a.RUSTFLAGS + " -C link-arg=-fuse-ld=mold"; }
                else
                  {
                    env =
                      (a.env or { })
                      // (cMoldFlags.env or { })
                      // {
                        RUSTFLAGS = toString ((a.env or { }).RUSTFLAGS or "") + " -C link-arg=-fuse-ld=mold";
                      };
                  };

              # ccacheFlags chains env from rustMoldFlags (which already chains
              # cMoldFlags.env) so the final // merge doesn't clobber prior env keys.
              # The preConfigure snippet is guarded by a directory existence check so
              # builds proceed normally when the ccache dir is not mounted.
              # preConfigure is only string-appended when the existing value is a
              # string (or absent); function-style preConfigure is left untouched.
              ccacheFlags =
                if !useCcache then
                  { }
                else
                  {
                    env =
                      (a.env or { })
                      // (rustMoldFlags.env or { })
                      // {
                        CCACHE_DIR = "/var/cache/ccache";
                        CCACHE_REMOTE_STORAGE = "file:///var/cache/ccache-r2-local|umask=002|layout=subdirs file:///var/cache/ccache-r2|read-only|umask=002|layout=subdirs";
                        CCACHE_SLOPPINESS = "include_file_ctime,include_file_mtime,random_seed,time_macros";
                        CCACHE_BASEDIR = "/build";
                        CCACHE_MAXSIZE = "200G";
                        CCACHE_COMPRESS = "true";
                        CCACHE_COMPRESSLEVEL = "6";
                        CCACHE_NOHASHDIR = "true";
                        CCACHE_UMASK = "007";
                      };
                    preConfigure =
                      let
                        existing = a.preConfigure or null;
                        # Leading newline prevents syntax errors when this hook is
                        # appended to a package's existing preConfigure string that
                        # doesn't end with a newline.
                        hook = ''

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
                          fi
                        '';
                      in
                      # Only string-append when preConfigure is absent or a plain string.
                      # Function-style preConfigure is passed through unchanged.
                      # Any other type (list, derivation, etc.) is also passed through
                      # unchanged to avoid type errors; ccache simply won't wrap in
                      # those rare cases.
                      if existing == null then
                        hook
                      else if builtins.isString existing then
                        existing + hook
                      else if builtins.isFunction existing then
                        existing
                      else
                        existing;
                  };
            in
            {
              doCheck = false;
              hardeningEnable =
                if useHardening then
                  prev.lib.unique ((a.hardeningEnable or [ ]) ++ hardeningFlags)
                else
                  (a.hardeningEnable or [ ]);
              nativeBuildInputs =
                (if useMold then (a.nativeBuildInputs or [ ]) ++ [ cleanMold ] else (a.nativeBuildInputs or [ ]))
                ++ (if useCcache then [ cleanCcache ] else [ ]);
            }
            // cMoldFlags
            // rustMoldFlags
            // ccacheFlags;
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
