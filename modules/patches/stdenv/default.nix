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
  # The flag names list is also used to generate stripping lines in
  # the compiler wrapper (see @GCC_FLAG_STRIP@ placeholder).
  gccOnlyFlags = [
    "-ftree-partial-pre" # More aggressive partial redundancy elimination
    "-fsplit-paths" # Path splitting for better DCE/CSE
    "-fgcse-after-reload" # Post-register-allocation redundancy elimination
    "-funswitch-loops" # Move loop-invariant conditions outside loops
    "-fpeel-loops" # Peel initial/final loop iterations
    "-fpredictive-commoning" # Reuse computations from previous loop iterations
    "-ftree-loop-distribution" # Split loops for better cache behavior
    "-floop-interchange" # Reorder nested loops for cache optimization
    "-floop-unroll-and-jam" # Unroll outer loops and fuse inner loops
  ];
  gccOptimizationFragment = lib.concatMapStrings (f: " ${f}") gccOnlyFlags;

  # Bash lines that strip each GCC-only flag from NIX_CFLAGS_COMPILE.
  # Substituted into compiler-wrapper.sh as @GCC_FLAG_STRIP@.
  gccFlagStripLines = lib.concatMapStrings (
    f: "  NIX_CFLAGS_COMPILE=\"\${NIX_CFLAGS_COMPILE// ${f}/}\"\n"
  ) gccOnlyFlags;

  # Optimization flags supported by both GCC (5.3+) and Clang (13+).
  universalOptimizationFragment = lib.concatStrings [
    " -fno-semantic-interposition" # Assume functions cannot be interposed; enables direct calls
    " -pipe" # Use pipes instead of temp files between stages (faster compilation)
    " -fno-var-tracking" # Skip expensive DWARF var-tracking pass (10-20% faster compilation)
  ];

  # Fallback march/mtune values for bootstrap stages where the compiler (GCC 14)
  # may not recognise newer architecture names added in GCC 15+.
  bootstrapMarchFallback = {
    arrowlake = "alderlake";
    arrowlake-s = "alderlake";
    lunarlake = "alderlake";
    pantherlake = "alderlake";
    clearwaterforest = "sierraforest";
    znver5 = "znver4";
  };
  bootstrapMarch =
    if config.cpuArch != null && bootstrapMarchFallback ? ${config.cpuArch} then
      bootstrapMarchFallback.${config.cpuArch}
    else
      config.cpuArch;
  bootstrapMarchFragment = lib.optionalString (bootstrapMarch != null) " -march=${bootstrapMarch}";

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
  bootstrapCflagsFragment = bootstrapMarchFragment + bootstrapMtuneFragment;

  # Compiler wrapper template as a store derivation.
  # See compiler-wrapper.sh for the full script.
  # @...@ placeholders are resolved at Nix eval time;
  # %...% placeholders are substituted by sed at build time.
  wrapperTemplate = nixpkgs-clean.writeText "compiler-wrapper-template" (
    builtins.replaceStrings
      [ "@CPU_ARCH@" "@CPU_TUNE@" "@CCACHE_BIN@" "@GCC_FLAG_STRIP@" ]
      [
        (if config.cpuArch != null then config.cpuArch else "")
        (if config.cpuTune != null then config.cpuTune else "")
        "${cleanCcache}/bin/ccache"
        gccFlagStripLines
      ]
      (builtins.readFile ./compiler-wrapper.sh)
  );

  # Cargo wrapper as a store derivation.
  # See cargo-wrapper.sh for the full script.
  cargoWrapperTemplate = nixpkgs-clean.writeText "cargo-wrapper-template" (
    builtins.replaceStrings [ "@WRAPPER_TEMPLATE@" ] [ "${wrapperTemplate}" ] (
      builtins.readFile ./cargo-wrapper.sh
    )
  );

  # Resolve a compiler name to its absolute path, skipping the wrapper dir.
  # See resolve-unwrapped.sh — no placeholders, takes wrap-dir as an argument.
  resolveUnwrapped = ./resolve-unwrapped.sh;

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
      _wrap_dir=/build/.ccache-wrap
      mkdir -p "$_wrap_dir"
      install -m755 ${resolveUnwrapped} "$_wrap_dir/_resolve_unwrapped"
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
        sed -e "s|%REAL_COMPILER%|$2|g" \
          ${wrapperTemplate} > "$1"
        chmod +x "$1"
      }
      _mkwrapper "$_wrap_dir/$_cc_name" "$_orig_cc"
      _mkwrapper "$_wrap_dir/$_cxx_name" "$_orig_cxx"
      export CC="$_wrap_dir/$_cc_name"
      export CXX="$_wrap_dir/$_cxx_name"
      echo >&2 "ccache: CC=$_orig_cc -> $CC"
      echo >&2 "ccache: CXX=$_orig_cxx -> $CXX"

      # Also wrap gcc/g++ and other compiler names that build systems (qmake,
      # hand-written Makefiles) may invoke directly instead of using $CC/$CXX.
      # This ensures ccache is used even when the compiler is called by name.
      for _extra in gcc g++ cc c++ clang clang++ xgcc xg++; do
        if [ ! -e "$_wrap_dir/$_extra" ]; then
          _extra_path="$(command -v "$_extra" 2>/dev/null)" || continue
          _mkwrapper "$_wrap_dir/$_extra" "$_extra_path"
          echo >&2 "ccache: PATH wrapper $_extra -> $_extra_path"
        fi
      done
      export PATH="$_wrap_dir:$PATH"

      # Rust: nixpkgs cargo build hooks run `env CC_<target>=<store-path> cargo build`.
      # The cc crate prefers CC_<target> over CC, so our ccache-wrapped CC is bypassed.
      # Fix: interpose a cargo wrapper (found via PATH) that rewrites CC_*/CXX_*/HOST_*
      # to ccache wrappers before exec-ing the real cargo.
      _real_cargo="$("$_wrap_dir/_resolve_unwrapped" "$_wrap_dir" cargo)"
      if [[ "$_real_cargo" == /* ]]; then
        sed -e "s|%WRAP_DIR%|$_wrap_dir|g" -e "s|%REAL_CARGO%|$_real_cargo|g" \
          ${cargoWrapperTemplate} > "$_wrap_dir/cargo"
        chmod +x "$_wrap_dir/cargo"
        echo >&2 "ccache: wrapped cargo -> $_real_cargo"
      fi

      # Haskell: setupCompilerEnvironmentPhase (a prePhase) bakes $CC into
      # configureFlags as --with-gcc=<path> before preConfigure runs.  Patch
      # the already-resolved path so GHC uses the ccache wrapper too.
      if [[ "''${configureFlags:-}" == *--with-gcc=* ]]; then
        configureFlags="$(echo "$configureFlags" | sed "s|--with-gcc=[^ ]*|--with-gcc=$CC|g")"
        echo >&2 "ccache: rewrote configure flag --with-gcc -> $CC"
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
      echo >&2 "ccache: cmakeFlagsArray=(''${cmakeFlagsArray[*]})"

      # Rewrite CC/CXX/HOSTCC/HOSTCXX in makeFlags so command-line
      # variables don't shadow the env-var wrappers above.
      if declare -p makeFlags &>/dev/null; then
        case "$(declare -p makeFlags 2>/dev/null)" in
          "declare -a"*)
            # Structured attrs / bash array
            for _i in "''${!makeFlags[@]}"; do
              case "''${makeFlags[$_i]}" in
                CC=*|CXX=*|HOSTCC=*|HOSTCXX=*)
                  _flagname="''${makeFlags[$_i]%%=*}"
                  _flagval="''${makeFlags[$_i]#*=}"
                  if [[ "''${_flagval#"$_wrap_dir"/}" != "$_flagval" ]]; then continue; fi
                  _flagval="$("$_wrap_dir/_resolve_unwrapped" "$_wrap_dir" "$_flagval")"
                  _base="$(basename "''${_flagval%% *}")"
                  _wrapper="$_wrap_dir/$_base-$_flagname"
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
                  if [[ "''${_flagval#"$_wrap_dir"/}" != "$_flagval" ]]; then _new_flags="$_new_flags $_tok"; continue; fi
                  _flagval="$("$_wrap_dir/_resolve_unwrapped" "$_wrap_dir" "$_flagval")"
                  _base="$(basename "''${_flagval%% *}")"
                  _wrapper="$_wrap_dir/$_base-$_flagname"
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
      #   - libcxxhardeningextensive: libc++ hardening (-D_LIBCPP_HARDENING_MODE=...
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
        "babl" # mold breaks dlopen-based SIMD extension loading at runtime
      ];

      # Packages excluded from optimization flags by pname.
      optimizationExcludedNames = [
        "ppp" # -fno-semantic-interposition triggers GCC bug with glibc fortified always_inline wrappers
        "tpm2-tss" # -fno-semantic-interposition triggers GCC bug with glibc fortified always_inline wrappers
        "usrsctp" # optimization flags expose -Wmaybe-uninitialized in mbuf code; package uses -Werror
        "libcamera" # -fno-semantic-interposition triggers GCC bug with glibc fortified always_inline wrappers
        "babl" # -fno-semantic-interposition breaks dlopen-based extension loading
        "umockdev" # -fno-semantic-interposition triggers GCC bug with glibc fortified always_inline wrappers
        # NixOSBuild AUTOFIX
        # Package name: hiredis
        # Error details: -Werror=stringop-overflow in sds.c — GCC tree-path optimization flags cause
        #   aggressive inlining of sdsll2str into sdsfromlonglong, triggering a false-positive
        #   stringop-overflow warning that hiredis's own -Werror promotes to an error.
        # Fix explanation: Excluding from optimization flags prevents the inlining that exposes the
        #   false positive; hiredis's -Werror remains but the overflow is no longer triggered.
        "hiredis" # GCC tree optimization flags trigger -Werror=stringop-overflow in sds.c (false positive from aggressive inlining)
        # NixOSBuild AUTOFIX
        # Package name: libyuv
        # Error details: GCC optimization flags (-ftree-partial-pre, -fsplit-paths, etc.) cause
        #   aggressive inlining analysis in unit_test/planar_test.cc, generating hundreds of
        #   false-positive -Wstringop-overflow= warnings from glibc's __builtin___memset_chk.
        #   The volume of warnings causes the compilation to hang, and nix kills the stray build.
        # Fix explanation: Excluding from optimization flags prevents the aggressive inlining
        #   that triggers the false-positive analysis, allowing planar_test.cc to compile in
        #   reasonable time.
        "libyuv" # GCC optimization flags trigger massive false-positive stringop-overflow analysis in planar_test.cc
        # NixOSBuild AUTOFIX
        # Package name: uharfbuzz 0.51.1
        # Error details: GCC optimization flags (-ftree-partial-pre, -fsplit-paths, etc.) cause the
        #   compiler to hang when processing harfbuzz-subset.cc, a large amalgamated C++ source file.
        #   The remote builder timed out after 1800 seconds of silence during compilation.
        # Fix explanation: Excluding from optimization flags prevents the expensive tree-based analysis
        #   on this large compilation unit, allowing it to complete in reasonable time.
        "uharfbuzz" # GCC optimization flags cause compiler to hang on harfbuzz-subset.cc (large amalgam)
      ];

      # Packages excluded from -march/-mtune arch flags by pname.
      # Use this for cross-compilation packages where x86 arch flags are
      # invalid (e.g. wasm32, aarch64 targets).  These packages still
      # receive optimization flags.
      archExcludedNames = [
        "compiler-rt" # wasm32 variant rejects -march for non-x86 targets; pname is shared with native build
        "libcxx" # wasm32 variant rejects -march for non-x86 targets; pname is shared with native build
        "babl" # -march=x86-64-v3 conflicts with babl's own runtime SIMD extension loading
        "qtbase" # -march=x86-64-v3 implies F16C; Qt5 configure detects it and defines QFLOAT16_INCLUDE_FAST causing redefinition errors
      ];

      # Packages excluded from GCC-only optimization flags by pname.
      # Use this for packages that invoke clang/libclang internally (e.g. via
      # rust-bindgen) where the compiler wrapper cannot intercept the call.
      # These packages still receive universal optimization flags.
      gccFlagExcludedNames = [
        "mesa" # rust-bindgen passes NIX_CFLAGS_COMPILE to libclang, which rejects GCC flags
        "libsignal-node" # boring-sys uses bindgen/libclang internally
        "deno" # uses bindgen/libclang internally
        "thin-provisioning-tools" # devicemapper-sys uses bindgen/libclang internally
        "hotdoc" # C extension invokes clang/libclang internally
        "yubioath-flutter" # Flutter Linux build uses clang++ internally
        "gstreamer-vaapi" # hotdoc build step invokes clang internally
        "helvum" # libspa-sys uses bindgen/libclang internally
        "pyside6" # shiboken invokes clang++ internally for Qt binding generation
        # KDE Frameworks packages that generate Python bindings via shiboken/clang
        "kcoreaddons"
        "kguiaddons"
        "knotifications"
        "kstatusnotifieritem"
        "kunitconversion"
        "kwidgetsaddons"
        "kxmlgui"
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
              useArch = !(a ? pname && builtins.elem a.pname archExcludedNames);
              effectiveCflags =
                if !useArch then
                  ""
                else if isBootstrap then
                  bootstrapCflagsFragment
                else
                  cflagsFragment;

              # Bootstrap compilers are always GCC (14 or 15); reading
              # _stdenv.cc in bootstrap would cause infinite recursion.
              isGNU = isBootstrap || (_stdenv.cc.isGNU or false);
              useGccFlags = isGNU && !(a ? pname && builtins.elem a.pname gccFlagExcludedNames);
              useOptimization = !(a ? pname && builtins.elem a.pname optimizationExcludedNames);

              # Combined cflags: arch flags (always) + optimization flags (non-bootstrap only).
              # Must be a single string since NIX_CFLAGS_COMPILE can only be set once.
              optimizationCflags =
                (if useGccFlags then gccOptimizationFragment else "") + universalOptimizationFragment;
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
