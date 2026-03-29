# NixOS module that provides a clean nixpkgs (no stdenv overlays) as a module argument.
# Used by the stdenv module to obtain mold/ccache without circular dependencies.
# Modules can append overlays via `nixpkgs-clean.overlays` (e.g. coreutils test patches).
# The evaluated package set is exposed as the `nixpkgs-clean` module argument.
{
  lib,
  config,
  system,
  nixpkgs-input,
  ...
}:
{
  options.nixpkgs-clean = {
    overlays = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [ ];
      description = "Overlays to apply to the clean nixpkgs package set";
    };
    pkgs = lib.mkOption {
      type = lib.types.unspecified;
      readOnly = true;
      description = "The evaluated clean nixpkgs package set (with overlays applied)";
    };
  };

  config.nixpkgs-clean.pkgs = import nixpkgs-input {
    inherit system;
    config = {
      allowUnfree = true;
      contentAddressedByDefault = true;
    };
    overlays = [
      # Only a few binaries (mold, ccache) are used from this set to
      # bootstrap the real stdenv, so running test suites is wasted work.
      (
        _final: prev:
        let
          baseMkDerivation = import "${prev.path}/pkgs/stdenv/generic/make-derivation.nix" {
            inherit (prev) lib config;
          };
        in
        {
          stdenv = prev.stdenv.override {
            mkDerivationFromStdenv =
              stdenv: args:
              let
                noChecks = {
                  doCheck = false;
                  doInstallCheck = false;
                  checkInputs = [ ];
                  nativeCheckInputs = [ ];
                  nativeInstallCheckInputs = [ ];
                };
                # args can be an attrset or a function (finalAttrs: { ... })
                args' =
                  if builtins.isFunction args then (finalAttrs: (args finalAttrs) // noChecks) else args // noChecks;
              in
              (baseMkDerivation stdenv).mkDerivation args';
          };
        }
      )

      # Statically link mold and ccache so they have no runtime deps on clean nixpkgs libs.
      (
        _final: prev:
        let
          ltoFlag = "-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON";

          mkStatic =
            pkg:
            pkg.overrideAttrs (old: {
              cmakeFlags = (old.cmakeFlags or [ ]) ++ [
                "-DBUILD_SHARED_LIBS=OFF"
                ltoFlag
              ];
              env = (old.env or { }) // {
                NIX_CFLAGS_COMPILE = toString (old.env.NIX_CFLAGS_COMPILE or "") + " -ffat-lto-objects";
              };
            });
          # zstd uses BUILD_STATIC/BUILD_SHARED instead of BUILD_SHARED_LIBS.
          staticZstd = (prev.zstd.override { enableStatic = true; }).overrideAttrs (old: {
            cmakeFlags = (old.cmakeFlags or [ ]) ++ [ ltoFlag ];
            env = (old.env or { }) // {
              NIX_CFLAGS_COMPILE = toString (old.env.NIX_CFLAGS_COMPILE or "") + " -ffat-lto-objects";
            };
          });
          mkStaticInput = pkg: if pkg.pname or "" == "zstd" then staticZstd else mkStatic pkg;
        in
        {
          # nixpkgs stable: bare binary is `mold`, wrapped is `mold-wrapped`.
          # nixpkgs unstable renames these to `mold-unwrapped` and `mold`.
          mold = prev.mold.overrideAttrs (old: {
            buildInputs = map mkStaticInput (old.buildInputs or [ ]);
            cmakeFlags = (old.cmakeFlags or [ ]) ++ [
              "-DMOLD_MOSTLY_STATIC:BOOL=ON"
              "-DMOLD_USE_SYSTEM_MIMALLOC:BOOL=OFF"
              "-DMOLD_USE_SYSTEM_TBB:BOOL=OFF"
              ltoFlag
            ];
          });

          ccache = prev.ccache.overrideAttrs (old: {
            outputs = [ "out" ];
            nativeBuildInputs = builtins.filter (i: i != prev.asciidoctor) old.nativeBuildInputs;
            buildInputs = map mkStaticInput (old.buildInputs or [ ]);
            cmakeFlags = (old.cmakeFlags or [ ]) ++ [
              "-DSTATIC_LINK=ON"
              "-DDEPS=LOCAL"
              ltoFlag
            ];
          });
        }
      )
    ]
    ++ config.nixpkgs-clean.overlays;
  };

  config._module.args.nixpkgs-clean = config.nixpkgs-clean.pkgs;
}
