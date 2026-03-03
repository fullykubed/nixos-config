{ pkgs, lib, ... }:

let
  bun2nix = pkgs.bun2nix-cli;
in
pkgs.stdenv.mkDerivation {
  pname = "credential-proxy";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [
    pkgs.makeWrapper
    bun2nix.hook
  ];

  # Pre-fetched Bun dependencies (no network needed during build)
  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/credential-proxy

    # Copy source files and node_modules installed by bun2nix hook
    cp -r src package.json tsconfig.json node_modules $out/lib/credential-proxy/

    # Create wrapper that runs main.ts with bun
    makeWrapper ${pkgs.bun}/bin/bun $out/bin/credential-proxy \
      --add-flags "$out/lib/credential-proxy/src/main.ts"

    runHook postInstall
  '';

  meta = with lib; {
    description = "MITM proxy for injecting credentials into HTTPS requests";
    license = licenses.mit;
    mainProgram = "credential-proxy";
    platforms = platforms.linux;
  };
}
