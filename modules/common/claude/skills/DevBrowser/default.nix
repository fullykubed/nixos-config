{ pkgs, lib, ... }:
let
  bun2nix = pkgs.bun2nix-cli;

  package = pkgs.stdenv.mkDerivation {
    pname = "dev-browser";
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

      mkdir -p $out/bin $out/lib/dev-browser

      # Copy source files and node_modules installed by bun2nix hook
      cp -r src package.json tsconfig.json node_modules $out/lib/dev-browser/

      # Create wrapper for CLI
      makeWrapper ${pkgs.bun}/bin/bun $out/bin/dev-browser \
        --add-flags "$out/lib/dev-browser/src/cli.ts" \
        --set CHROMIUM_PATH "${pkgs.chromium}/bin/chromium" \
        --set PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD "1" \
        --set FONTCONFIG_FILE "${pkgs.fontconfig.out}/etc/fonts/fonts.conf" \
        --set FONTCONFIG_PATH "${pkgs.fontconfig.out}/etc/fonts"

      # Create wrapper for server
      makeWrapper ${pkgs.bun}/bin/bun $out/bin/dev-browser-server \
        --add-flags "$out/lib/dev-browser/src/server.ts" \
        --set CHROMIUM_PATH "${pkgs.chromium}/bin/chromium" \
        --set PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD "1" \
        --set FONTCONFIG_FILE "${pkgs.fontconfig.out}/etc/fonts/fonts.conf" \
        --set FONTCONFIG_PATH "${pkgs.fontconfig.out}/etc/fonts"

      runHook postInstall
    '';

    meta = with lib; {
      description = "Browser automation CLI for Claude Code";
      license = licenses.mit;
      mainProgram = "dev-browser";
      platforms = platforms.linux;
    };
  };
in
{
  inherit package;
  homeFiles = {
    ".claude/skills/DevBrowser" = {
      source = ./.;
      recursive = true;
    };
  };
}
