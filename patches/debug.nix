# Debug utilities for tracing crashes in Nix builds
#
# Usage in patches/default.nix:
#
#   let
#     debug = import ./debug.nix {
#       inherit (prev) lib writeShellScript gdb strace valgrind coreutils;
#     };
#   in
#   {
#     # Wrap a package's checkPhase to trace crashes
#     somePackage = debug.tracePackage prev.somePackage {
#       testBinary = "./tests/failing-test";
#       # Optional: specific test args
#       testArgs = [ "--verbose" ];
#     };
#
#     # Or manually use the wrapper script in any phase
#     anotherPackage = prev.anotherPackage.overrideAttrs (old: {
#       nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ debug.wrapper ];
#       checkPhase = ''
#         debug-trace ./my-test
#       '';
#     });
#
#     # Trace with strace (syscalls)
#     pkg = prev.pkg.overrideAttrs (old: {
#       nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ debug.straceWrapper ];
#       checkPhase = ''debug-strace ./test'';
#     });
#
#     # Trace with valgrind (memory)
#     pkg = prev.pkg.overrideAttrs (old: {
#       nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ debug.valgrindWrapper ];
#       checkPhase = ''debug-valgrind ./test'';
#     });
#   }
#
{
  lib,
  writeShellScript,
  gdb,
  strace ? null,
  valgrind ? null,
  coreutils,
}:

let
  # GDB batch script that catches signals and prints detailed traces
  gdbCommands = writeShellScript "gdb-trace-commands" ''
    set pagination off
    set print frame-arguments all
    set print entry-values no
    set filename-display absolute
    set print pretty on
    set print array on
    set print array-indexes on

    # Stop on common crash signals
    handle SIGABRT stop print
    handle SIGSEGV stop print
    handle SIGFPE stop print
    handle SIGBUS stop print
    handle SIGILL stop print
    handle SIGTRAP stop print

    # Run the program
    run

    # On crash, print everything useful
    echo \n=== CRASH DETECTED ===\n

    echo \n--- All Threads Backtrace ---\n
    thread apply all bt full

    echo \n--- Current Thread Backtrace (full) ---\n
    bt full

    echo \n--- Source context (frames 0-7) ---\n
    frame 0
    list
    info args
    info locals
    frame 1
    list
    info args
    info locals
    frame 2
    list
    frame 3
    list
    frame 4
    list
    frame 5
    list
    frame 6
    list
    frame 7
    list

    echo \n--- Register state ---\n
    info registers

    echo \n--- Memory maps ---\n
    info proc mappings

    echo \n--- Shared libraries ---\n
    info sharedlibrary

    echo \n=== END CRASH TRACE ===\n
    quit 1
  '';

  # Wrapper script that runs a binary under GDB batch mode
  wrapper = writeShellScript "debug-trace" ''
    set -uo pipefail

    if [ $# -lt 1 ]; then
      echo "Usage: debug-trace <binary> [args...]"
      echo "Runs binary under GDB to trace crashes (SIGABRT, SIGSEGV, etc.)"
      exit 1
    fi

    binary="$1"
    shift

    echo "══════════════════════════════════════════════════════════════"
    echo "DEBUG TRACE: $binary $*"
    echo "══════════════════════════════════════════════════════════════"

    # Run under GDB batch mode
    ${gdb}/bin/gdb -batch -x ${gdbCommands} --args "$binary" "$@" 2>&1
    exit_code=$?

    echo "══════════════════════════════════════════════════════════════"
    echo "DEBUG TRACE: Exit code $exit_code"
    echo "══════════════════════════════════════════════════════════════"

    exit $exit_code
  '';

  # Function to wrap a package's tests with crash tracing
  #
  # Args:
  #   pkg: The package to wrap
  #   opts: {
  #     testBinary: Path to the test binary (required)
  #     testArgs: List of arguments to pass (default: [])
  #     phase: Which phase to override (default: "checkPhase")
  #     keepOriginalPhase: Run original phase after trace (default: false)
  #   }
  #
  tracePackage =
    pkg:
    {
      testBinary,
      testArgs ? [ ],
      phase ? "checkPhase",
      keepOriginalPhase ? false,
    }:
    pkg.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ gdb ];
      dontStrip = true;

      # Add debug symbols
      env = (old.env or { }) // {
        NIX_CFLAGS_COMPILE = (old.env.NIX_CFLAGS_COMPILE or "") + " -g -O0 -fno-omit-frame-pointer";
      };

      ${phase} = ''
        runHook pre${lib.removePrefix "c" (lib.removePrefix "C" phase)}

        echo "══════════════════════════════════════════════════════════════"
        echo "DEBUG TRACE: ${testBinary} ${toString testArgs}"
        echo "══════════════════════════════════════════════════════════════"

        ${gdb}/bin/gdb -batch -x ${gdbCommands} --args ${testBinary} ${toString testArgs} 2>&1 || true

        ${lib.optionalString keepOriginalPhase (old.${phase} or "")}

        runHook post${lib.removePrefix "c" (lib.removePrefix "C" phase)}
      '';
    });

  # ASAN-enabled build for memory error detection
  # Gives automatic line numbers for memory corruption without GDB
  #
  # Usage:
  #   somePackage = debug.withAsan prev.somePackage;
  #
  withAsan =
    pkg:
    pkg.overrideAttrs (old: {
      dontStrip = true;
      env = (old.env or { }) // {
        NIX_CFLAGS_COMPILE =
          (old.env.NIX_CFLAGS_COMPILE or "") + " -g -O0 -fsanitize=address -fno-omit-frame-pointer";
        NIX_LDFLAGS = (old.env.NIX_LDFLAGS or "") + " -fsanitize=address";
      };

      # ASAN runtime options for detailed output
      preBuild = (old.preBuild or "") + ''
        export ASAN_OPTIONS="symbolize=1:detect_leaks=1:abort_on_error=1:print_legend=1"
        export ASAN_SYMBOLIZER_PATH="${lib.getBin gdb}/bin/gdb"
      '';
    });

  # Combine GDB tracing with ASAN for comprehensive debugging
  #
  # Usage:
  #   somePackage = debug.fullDebug prev.somePackage {
  #     testBinary = "./test";
  #   };
  #
  fullDebug = pkg: opts: tracePackage (withAsan pkg) opts;

  # strace wrapper - trace syscalls leading to crash
  straceWrapper = lib.optionalAttrs (strace != null) (
    writeShellScript "debug-strace" ''
      set -uo pipefail

      if [ $# -lt 1 ]; then
        echo "Usage: debug-strace <binary> [args...]"
        exit 1
      fi

      binary="$1"
      shift

      echo "══════════════════════════════════════════════════════════════"
      echo "STRACE: $binary $*"
      echo "══════════════════════════════════════════════════════════════"

      ${strace}/bin/strace -f -s 256 -tt -T \
        -e trace=all \
        -o /dev/stderr \
        "$binary" "$@" 2>&1

      echo "══════════════════════════════════════════════════════════════"
    ''
  );

  # Valgrind wrapper - detailed memory analysis
  valgrindWrapper = lib.optionalAttrs (valgrind != null) (
    writeShellScript "debug-valgrind" ''
      set -uo pipefail

      if [ $# -lt 1 ]; then
        echo "Usage: debug-valgrind <binary> [args...]"
        exit 1
      fi

      binary="$1"
      shift

      echo "══════════════════════════════════════════════════════════════"
      echo "VALGRIND: $binary $*"
      echo "══════════════════════════════════════════════════════════════"

      ${valgrind}/bin/valgrind \
        --leak-check=full \
        --show-leak-kinds=all \
        --track-origins=yes \
        --track-fds=yes \
        --error-exitcode=1 \
        --num-callers=30 \
        "$binary" "$@" 2>&1

      echo "══════════════════════════════════════════════════════════════"
    ''
  );

  # Combined wrapper - runs GDB, captures output, and optionally strace
  combinedWrapper = writeShellScript "debug-full" ''
    set -uo pipefail

    show_help() {
      echo "Usage: debug-full [options] <binary> [args...]"
      echo ""
      echo "Options:"
      echo "  --strace     Also run strace (syscall trace)"
      echo "  --valgrind   Also run valgrind (memory analysis)"
      echo "  --timeout N  Kill after N seconds (default: 300)"
      echo "  --output F   Save output to file F"
      echo ""
    }

    use_strace=false
    use_valgrind=false
    timeout_sec=300
    output_file=""

    while [ $# -gt 0 ]; do
      case "$1" in
        --strace) use_strace=true; shift ;;
        --valgrind) use_valgrind=true; shift ;;
        --timeout) timeout_sec="$2"; shift 2 ;;
        --output) output_file="$2"; shift 2 ;;
        --help|-h) show_help; exit 0 ;;
        --) shift; break ;;
        -*) echo "Unknown option: $1"; show_help; exit 1 ;;
        *) break ;;
      esac
    done

    if [ $# -lt 1 ]; then
      show_help
      exit 1
    fi

    binary="$1"
    shift

    run_debug() {
      echo "══════════════════════════════════════════════════════════════"
      echo "DEBUG FULL: $binary $*"
      echo "Timeout: ''${timeout_sec}s | strace: $use_strace | valgrind: $use_valgrind"
      echo "══════════════════════════════════════════════════════════════"

      if [ "$use_strace" = true ]; then
        echo ""
        echo "--- STRACE OUTPUT ---"
        ${coreutils}/bin/timeout "$timeout_sec" \
          ${strace}/bin/strace -f -s 256 -tt "$binary" "$@" 2>&1 || true
        echo "--- END STRACE ---"
        echo ""
      fi

      if [ "$use_valgrind" = true ]; then
        echo ""
        echo "--- VALGRIND OUTPUT ---"
        ${coreutils}/bin/timeout "$timeout_sec" \
          ${valgrind}/bin/valgrind --leak-check=full --track-origins=yes \
          "$binary" "$@" 2>&1 || true
        echo "--- END VALGRIND ---"
        echo ""
      fi

      echo ""
      echo "--- GDB TRACE ---"
      ${coreutils}/bin/timeout "$timeout_sec" \
        ${gdb}/bin/gdb -batch -x ${gdbCommands} --args "$binary" "$@" 2>&1 || true
      echo "--- END GDB TRACE ---"

      echo "══════════════════════════════════════════════════════════════"
    }

    if [ -n "$output_file" ]; then
      run_debug "$@" 2>&1 | ${coreutils}/bin/tee "$output_file"
    else
      run_debug "$@"
    fi
  '';

  # UBSan (Undefined Behavior Sanitizer) build
  withUbsan =
    pkg:
    pkg.overrideAttrs (old: {
      dontStrip = true;
      env = (old.env or { }) // {
        NIX_CFLAGS_COMPILE =
          (old.env.NIX_CFLAGS_COMPILE or "") + " -g -O0 -fsanitize=undefined -fno-omit-frame-pointer";
        NIX_LDFLAGS = (old.env.NIX_LDFLAGS or "") + " -fsanitize=undefined";
      };
      preBuild = (old.preBuild or "") + ''
        export UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=1"
      '';
    });

  # TSan (Thread Sanitizer) build - for race conditions
  withTsan =
    pkg:
    pkg.overrideAttrs (old: {
      dontStrip = true;
      env = (old.env or { }) // {
        NIX_CFLAGS_COMPILE =
          (old.env.NIX_CFLAGS_COMPILE or "") + " -g -O0 -fsanitize=thread -fno-omit-frame-pointer";
        NIX_LDFLAGS = (old.env.NIX_LDFLAGS or "") + " -fsanitize=thread";
      };
      preBuild = (old.preBuild or "") + ''
        export TSAN_OPTIONS="second_deadlock_stack=1:halt_on_error=1"
      '';
    });

  # All sanitizers combined (ASAN + UBSan, note: TSan incompatible with ASAN)
  withAllSanitizers =
    pkg:
    pkg.overrideAttrs (old: {
      dontStrip = true;
      env = (old.env or { }) // {
        NIX_CFLAGS_COMPILE =
          (old.env.NIX_CFLAGS_COMPILE or "") + " -g -O0 -fsanitize=address,undefined -fno-omit-frame-pointer";
        NIX_LDFLAGS = (old.env.NIX_LDFLAGS or "") + " -fsanitize=address,undefined";
      };
      preBuild = (old.preBuild or "") + ''
        export ASAN_OPTIONS="symbolize=1:detect_leaks=1:abort_on_error=1"
        export UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=1"
      '';
    });

  # Trace multiple test binaries in sequence
  traceMultiple =
    pkg:
    {
      testBinaries,
      phase ? "checkPhase",
    }:
    pkg.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ gdb ];
      dontStrip = true;
      env = (old.env or { }) // {
        NIX_CFLAGS_COMPILE = (old.env.NIX_CFLAGS_COMPILE or "") + " -g -O0 -fno-omit-frame-pointer";
      };

      ${phase} = ''
        runHook preCheck
        ${lib.concatMapStringsSep "\n" (bin: ''
          echo ""
          echo "══════════════════════════════════════════════════════════════"
          echo "TRACING: ${bin}"
          echo "══════════════════════════════════════════════════════════════"
          ${gdb}/bin/gdb -batch -x ${gdbCommands} --args ${bin} 2>&1 || true
        '') testBinaries}
        runHook postCheck
      '';
    });

in
{
  inherit
    wrapper
    tracePackage
    withAsan
    fullDebug
    gdbCommands
    ;
  inherit straceWrapper valgrindWrapper combinedWrapper;
  inherit withUbsan withTsan withAllSanitizers;
  inherit traceMultiple;

  # Convenience: packages for manual use
  inherit gdb;
  inherit strace valgrind;
}
