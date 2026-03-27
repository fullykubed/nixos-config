# NixOS module that provides nixpkgs-unstable as a first-class module argument.
# Modules can append overlays via `nixpkgs-unstable.overlays`, mirroring `nixpkgs.overlays`.
# The evaluated package set is exposed as the `nixpkgs-unstable` module argument.
{
  lib,
  config,
  system,
  nixpkgs-unstable-input,
  ...
}:
{
  options.nixpkgs-unstable = {
    overlays = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [ ];
      description = "Overlays to apply to the unstable nixpkgs package set";
    };
    pkgs = lib.mkOption {
      type = lib.types.unspecified;
      readOnly = true;
      description = "The evaluated unstable nixpkgs package set (with overlays applied)";
    };
  };

  config.nixpkgs-unstable.pkgs = import nixpkgs-unstable-input {
    inherit system;
    config = {
      allowUnfree = true;
      contentAddressedByDefault = false; # temporarily disabled
    };
    inherit (config.nixpkgs-unstable) overlays;
  };

  config._module.args.nixpkgs-unstable = config.nixpkgs-unstable.pkgs;
}
