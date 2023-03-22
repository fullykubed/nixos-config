{ config, pkgs, lib, ... }: {
  options.nix-unstable = with lib; mkOption {
    default = {};
    type = types.attrs;
    description = "The nix-unstable source for bleeding-edge pacakges.";
  };
}