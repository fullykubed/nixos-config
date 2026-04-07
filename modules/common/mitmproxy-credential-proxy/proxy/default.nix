{ pkgs, lib, ... }:

let
  bun2nix = pkgs.bun2nix-cli;
in
bun2nix.mkDerivation {
  # pname + version come from ./package.json.
  packageJson = ./package.json;

  src = ./.;

  bunDeps = bun2nix.fetchBunDeps { bunNix = ./bun.nix; };

  module = "src/main.ts";

  meta = with lib; {
    description = "MITM proxy for injecting credentials into HTTPS requests";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
