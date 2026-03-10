# Custom stdenv with additional hardening flags and mold linker
#
# This module overrides the default stdenv to:
# 1. Enable additional hardening flags globally (trivialautovarinit)
# 2. Use the mold linker for all compatible packages (faster than GNU ld)
# 3. Disable reference checks to allow CVE patches on bootstrap packages
# 4. Exclude specific packages from aggressive hardening
#
# Mold is built from a clean nixpkgs import (no overlays) to avoid
# a circular dependency (mold needs stdenv, our stdenv adds mold).
#
# Per-package test/build overrides caused by the custom stdenv live in modules/patches/.
# Packages can opt out of mold by setting __noMold = true via overrideAttrs.
{
  lib,
  system,
  nixpkgs-unstable-input,
  ...
}:
let
  # Build mold from a clean nixpkgs import (no overlays) to avoid
  # circular dependency.
  cleanMold =
    (import nixpkgs-unstable-input {
      inherit system;
      config.allowUnfree = true;
    }).mold;

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
            in
            {
              doCheck = false;
              hardeningEnable =
                if useHardening then
                  prev.lib.unique ((a.hardeningEnable or [ ]) ++ hardeningFlags)
                else
                  (a.hardeningEnable or [ ]);
              nativeBuildInputs =
                if useMold then (a.nativeBuildInputs or [ ]) ++ [ cleanMold ] else (a.nativeBuildInputs or [ ]);
            }
            // cMoldFlags
            // rustMoldFlags;
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
