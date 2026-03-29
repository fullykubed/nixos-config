# Custom stdenv with additional hardening flags, mold linker, ccache, and optimization flags
#
# This module overrides the default stdenv to:
# 1. Enable additional hardening flags globally (trivialautovarinit)
# 2. Use the mold linker for all compatible packages (faster than GNU ld)
# 3. Use ccache as a C/C++ compiler wrapper for all compatible packages
# 4. Disable reference checks to allow CVE patches on bootstrap packages
# 5. Exclude specific packages from aggressive hardening
# 6. Inject per-compiler optimization flags (GCC-only and universal)
#
# Mold and ccache are built from a clean nixpkgs import (no overlays) to
# avoid a circular dependency (they need stdenv, our stdenv adds them).
#
# Per-package test/build overrides caused by the custom stdenv live in modules/patches/.
{
  lib,
  config,
  nixpkgs-clean,
  ...
}:
let
  # nixpkgs stable: `mold-wrapped` has the ld-wrapper that injects RPATH entries.
  # nixpkgs unstable renames this to just `mold`.
  cleanMold = nixpkgs-clean.mold-wrapped;
  cleanCcache = nixpkgs-clean.ccache;

  # The mold flag fragments.
  moldCFragment = " -fuse-ld=mold";
  moldRustFragment = " -C link-arg=-fuse-ld=mold";

  # Per-machine CPU architecture flag fragments.
  marchFragment = lib.optionalString (config.cpuArch != null) " -march=${config.cpuArch}";
  mtuneFragment = lib.optionalString (config.cpuTune != null) " -mtune=${config.cpuTune}";
  cflagsFragment = marchFragment + mtuneFragment;
  useCflags = cflagsFragment != "";

  # GCC-only optimization flags (cherry-picked from -O3, not in -O2).
  # These are GCC internal pass names; Clang will error on them.
  gccOptimizationFragment = lib.concatStrings [
    " -ftree-partial-pre" # More aggressive partial redundancy elimination
    " -fsplit-paths" # Path splitting for better DCE/CSE
    " -fgcse-after-reload" # Post-register-allocation redundancy elimination
    " -funswitch-loops" # Move loop-invariant conditions outside loops
    " -fpeel-loops" # Peel initial/final loop iterations
    " -fpredictive-commoning" # Reuse computations from previous loop iterations
    " -ftree-loop-distribution" # Split loops for better cache behavior
    " -floop-interchange" # Reorder nested loops for cache optimization
    " -floop-unroll-and-jam" # Unroll outer loops and fuse inner loops
  ];

  # Optimization flags supported by both GCC (5.3+) and Clang (13+).
  universalOptimizationFragment = lib.concatStrings [
    " -fno-semantic-interposition" # Assume functions cannot be interposed; enables direct calls
    " -pipe" # Use pipes instead of temp files between stages (faster compilation)
    " -fno-var-tracking" # Skip expensive DWARF var-tracking pass (10-20% faster compilation)
  ];

  # Fallback mtune values for bootstrap stages where the compiler (GCC 14)
  # may not recognise newer architecture names added in GCC 15+.
  bootstrapMtuneFallback = {
    arrowlake = "alderlake";
    arrowlake-s = "alderlake";
    lunarlake = "alderlake";
    pantherlake = "alderlake";
    clearwaterforest = "sierraforest";
    znver5 = "znver4";
  };
  bootstrapMtune =
    if config.cpuTune != null && bootstrapMtuneFallback ? ${config.cpuTune} then
      bootstrapMtuneFallback.${config.cpuTune}
    else
      config.cpuTune;
  bootstrapMtuneFragment = lib.optionalString (bootstrapMtune != null) " -mtune=${bootstrapMtune}";
  bootstrapCflagsFragment = marchFragment + bootstrapMtuneFragment;

  # Printf format for ccache wrapper scripts.
  # Slots: ccache-binary, real-compiler, real-compiler.
  wrapperFmt = ''#!/bin/sh\nfor _a in "$@"; do\n  if [ "$_a" = "-c" ]; then\n    exec %s %s "$@"\n  fi\ndone\nexec %s "$@"\n'';

  # Cargo wrapper: rewrites CC_<target>/CXX_<target>/HOST_CC/HOST_CXX set by
  # nixpkgs cargo build hooks to ccache wrappers before exec-ing real cargo.
  cargoWrapperScript = ''
    #!/bin/sh
    _w="''${CCACHE_WRAP_DIR}"
    _cb="''${CCACHE_BIN}"
    for _var in $(env | sed -n 's/^\(CC_[A-Za-z0-9_]*\)=.*/\1/p; s/^\(CXX_[A-Za-z0-9_]*\)=.*/\1/p') HOST_CC HOST_CXX; do
      eval "_val=\$$_var"
      if [ -z "$_val" ]; then continue; fi
      case "$_val" in "$_w"/*) continue ;; esac
      case "$_val" in /*) ;; *) continue ;; esac
      if [ ! -f "$_w/$_var" ]; then
        printf '${wrapperFmt}' "$_cb" "$_val" "$_val" > "$_w/$_var"
        chmod +x "$_w/$_var"
      fi
      export "$_var=$_w/$_var"
    done
    exec "''${CCACHE_REAL_CARGO}" "$@"
  '';

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
      # Resolve CC/CXX to absolute paths. The cc-wrapper setup hook may
      # export bare names (CC=gcc) rather than store paths; wrappers must
      # contain absolute paths so that `exec <compiler> "$@"` never
      # resolves back to the wrapper itself via PATH.
      _orig_cc="$(command -v "''${CC:-cc}" 2>/dev/null || echo "''${CC:-cc}")"
      _orig_cxx="$(command -v "''${CXX:-c++}" 2>/dev/null || echo "''${CXX:-c++}")"
      _cc_name="$(basename "$_orig_cc")"
      _cxx_name="$(basename "$_orig_cxx")"
      _ccache_bin="$(command -v ccache)"
      _mkwrapper() {
        if [[ "$2" == /* ]]; then
          printf '${wrapperFmt}' "$_ccache_bin" "$2" "$2" > "$1"
        else
          # Bare compiler name — skip ccache (would loop via PATH) but
          # still create a passthrough so $CC/$CXX work.
          printf '#!/bin/sh\nexec %s "$@"\n' "$2" > "$1"
        fi
        chmod +x "$1"
      }
      _mkwrapper "$_ccache_wrap/$_cc_name" "$_orig_cc"
      _mkwrapper "$_ccache_wrap/$_cxx_name" "$_orig_cxx"
      export CC="$_ccache_wrap/$_cc_name"
      export CXX="$_ccache_wrap/$_cxx_name"

      # Also wrap gcc/g++ and other compiler names that build systems (qmake,
      # hand-written Makefiles) may invoke directly instead of using $CC/$CXX.
      # This ensures ccache is used even when the compiler is called by name.
      for _extra in gcc g++ cc c++ clang clang++ xgcc xg++; do
        if [ ! -e "$_ccache_wrap/$_extra" ]; then
          _extra_path="$(command -v "$_extra" 2>/dev/null)" || continue
          _mkwrapper "$_ccache_wrap/$_extra" "$_extra_path"
        fi
      done
      export PATH="$_ccache_wrap:$PATH"

      # Rust: nixpkgs cargo build hooks run `env CC_<target>=<store-path> cargo build`.
      # The cc crate prefers CC_<target> over CC, so our ccache-wrapped CC is bypassed.
      # Fix: interpose a cargo wrapper (found via PATH) that rewrites CC_*/CXX_*/HOST_*
      # to ccache wrappers before exec-ing the real cargo.
      _real_cargo=""
      for _d in $(echo "$PATH" | tr ':' ' '); do
        if [ "$_d" = "$_ccache_wrap" ]; then continue; fi
        if [ -x "$_d/cargo" ]; then _real_cargo="$_d/cargo"; break; fi
      done
      if [ -n "$_real_cargo" ]; then
        printf '%s' ${lib.escapeShellArg cargoWrapperScript} > "$_ccache_wrap/cargo"
        chmod +x "$_ccache_wrap/cargo"
        export CCACHE_REAL_CARGO="$_real_cargo"
        export CCACHE_WRAP_DIR="$_ccache_wrap"
        export CCACHE_BIN="$_ccache_bin"
      fi

      # Haskell: setupCompilerEnvironmentPhase (a prePhase) bakes $CC into
      # configureFlags as --with-gcc=<path> before preConfigure runs.  Patch
      # the already-resolved path so GHC uses the ccache wrapper too.
      if [[ "''${configureFlags:-}" == *--with-gcc=* ]]; then
        configureFlags="$(echo "$configureFlags" | sed "s|--with-gcc=[^ ]*|--with-gcc=$CC|g")"
      fi

      # Tell cmake to use the real compiler with ccache as a launcher.
      # Everything is merged into cmakeFlagsArray so each -D flag stays a
      # separate array element. Packages like x265 and llvm-tblgen run
      # multiple cmake invocations and pass flags through quoted contexts
      # where a plain cmakeFlags string gets escaped into a single argument.
      # The cmakeFlags string is absorbed into the array and cleared so the
      # ordering is preserved (cmake last-wins):
      #   1. original cmakeFlags entries (lowest priority)
      #   2. ccache flags (override hook and package cmakeFlags)
      #   3. original cmakeFlagsArray entries (highest priority)
      # Harmless for non-cmake builds (cmakeFlagsArray is unused).
      _ccache_cmake_flags=(
        "-DCMAKE_C_COMPILER=$_orig_cc"
        "-DCMAKE_CXX_COMPILER=$_orig_cxx"
        "-DCMAKE_C_COMPILER_LAUNCHER=$_ccache_bin"
        "-DCMAKE_CXX_COMPILER_LAUNCHER=$_ccache_bin"
      )
      if [ -n "''${cmakeFlags:-}" ]; then
        read -ra _orig_cmake_flags <<< "$cmakeFlags"
        cmakeFlagsArray=("''${_orig_cmake_flags[@]}" "''${_ccache_cmake_flags[@]}" ''${cmakeFlagsArray[@]+"''${cmakeFlagsArray[@]}"})
      else
        cmakeFlagsArray=("''${_ccache_cmake_flags[@]}" ''${cmakeFlagsArray[@]+"''${cmakeFlagsArray[@]}"})
      fi
      cmakeFlags=""

      # Rewrite CC/CXX/HOSTCC/HOSTCXX in makeFlags so command-line
      # variables don't shadow the env-var wrappers above.
      # Resolve bare names using PATH minus the wrapper dir to avoid
      # wrapping an already-wrapped compiler.
      _resolve_compiler() {
        local _val="$1"
        if [[ "$_val" == /* ]]; then echo "$_val"; return; fi
        local _p
        IFS=: read -ra _dirs <<< "$PATH"
        for _p in "''${_dirs[@]}"; do
          if [ "$_p" = "$_ccache_wrap" ]; then continue; fi
          if [ -x "$_p/$_val" ]; then echo "$_p/$_val"; return; fi
        done
        echo "$_val"
      }
      if declare -p makeFlags &>/dev/null; then
        case "$(declare -p makeFlags 2>/dev/null)" in
          "declare -a"*)
            # Structured attrs / bash array
            for _i in "''${!makeFlags[@]}"; do
              case "''${makeFlags[$_i]}" in
                CC=*|CXX=*|HOSTCC=*|HOSTCXX=*)
                  _flagname="''${makeFlags[$_i]%%=*}"
                  _flagval="''${makeFlags[$_i]#*=}"
                  if [[ "''${_flagval#"$_ccache_wrap"/}" != "$_flagval" ]]; then continue; fi
                  _flagval="$(_resolve_compiler "$_flagval")"
                  _base="$(basename "''${_flagval%% *}")"
                  _wrapper="$_ccache_wrap/$_base-$_flagname"
                  _mkwrapper "$_wrapper" "$_flagval"
                  makeFlags[$_i]="$_flagname=$_wrapper"
                  echo >&2 "ccache: rewrote makeFlags $_flagname -> $_wrapper (was $_flagval)"
                  ;;
              esac
            done
            ;;
          "declare --"*|"declare -x"*)
            # Plain string
            _new_flags=""
            for _tok in $makeFlags; do
              case "$_tok" in
                CC=*|CXX=*|HOSTCC=*|HOSTCXX=*)
                  _flagname="''${_tok%%=*}"
                  _flagval="''${_tok#*=}"
                  if [[ "''${_flagval#"$_ccache_wrap"/}" != "$_flagval" ]]; then _new_flags="$_new_flags $_tok"; continue; fi
                  _flagval="$(_resolve_compiler "$_flagval")"
                  _base="$(basename "''${_flagval%% *}")"
                  _wrapper="$_ccache_wrap/$_base-$_flagname"
                  _mkwrapper "$_wrapper" "$_flagval"
                  _new_flags="$_new_flags $_flagname=$_wrapper"
                  echo >&2 "ccache: rewrote makeFlags $_flagname -> $_wrapper (was $_flagval)"
                  ;;
                *)
                  _new_flags="$_new_flags $_tok"
                  ;;
              esac
            done
            makeFlags="''${_new_flags# }"
            ;;
        esac
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
        "sbsigntool" # ccan Makefile re-reads .d files with stale glibc-dev paths; same class as kexec-tools
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

      # Packages excluded from optimization flags by pname.
      optimizationExcludedNames = [
        # Initially empty — populated as build failures are discovered
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
              effectiveCflags = if isBootstrap then bootstrapCflagsFragment else cflagsFragment;

              # Compiler detection: only safe to read _stdenv.cc outside bootstrap
              # (bootstrap stdenvs don't have a full .cc attr set).
              isGNU = !isBootstrap && (_stdenv.cc.isGNU or false);
              useOptimization = !isBootstrap && !(a ? pname && builtins.elem a.pname optimizationExcludedNames);

              # Combined cflags: arch flags (always) + optimization flags (non-bootstrap only).
              # Must be a single string since NIX_CFLAGS_COMPILE can only be set once.
              optimizationCflags =
                (if isGNU then gccOptimizationFragment else "") + universalOptimizationFragment;
              allCflags = effectiveCflags + (if useOptimization then optimizationCflags else "");
              useAnyCflags = useCflags || useOptimization;

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
                })
                // (prev.lib.optionalAttrs (useAnyCflags && !(a ? NIX_CFLAGS_COMPILE)) {
                  NIX_CFLAGS_COMPILE = toString (baseEnv.NIX_CFLAGS_COMPILE or "") + allCflags;
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
            // (prev.lib.optionalAttrs (useAnyCflags && a ? NIX_CFLAGS_COMPILE) {
              NIX_CFLAGS_COMPILE = toString a.NIX_CFLAGS_COMPILE + allCflags;
            })
            # Attribute NAME must not depend on a.preConfigure (a value from
            # originalAttrs).  In the make-derivation.nix fixpoint, attribute
            # names of the additions attrset are needed to resolve the `//`
            # merge, which would force evaluation of finalAttrs and recurse.
            # Gate on `useCcache` (depends only on pname) so the
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
