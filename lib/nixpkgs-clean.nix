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
    inherit (config.nixpkgs-clean) overlays;
  };

  config._module.args.nixpkgs-clean = config.nixpkgs-clean.pkgs;
}
