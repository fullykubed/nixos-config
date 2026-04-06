{
  pkgs,
  lib,
  versions,
  ...
}:
let
  src = pkgs.fetchFromGitHub {
    owner = "vercel-labs";
    repo = "agent-browser";
    rev = "v${versions.agentBrowser}";
    hash = versions.agentBrowserSrcHash;
  };

  # NixOSBuild AUTOFIX
  # agent-browser-daemon: switch from buildNpmPackage to pnpm_9 + fetchDeps
  # Error details: buildNpmPackage requires package-lock.json; agent-browser uses pnpm-lock.yaml (lockfileVersion 9.0)
  # Fix explanation: Use pnpm_9.fetchDeps (FOD that pre-fetches the pnpm store) with pnpm_9.configHook
  #   to make the pnpm store available offline, then run tsc to compile TypeScript to dist/.
  pnpmDeps = pkgs.pnpm_9.fetchDeps {
    pname = "agent-browser-daemon";
    version = versions.agentBrowser;
    inherit src;
    fetcherVersion = 3;
    hash = versions.agentBrowserPnpmDepsHash;
  };

  daemon = pkgs.stdenv.mkDerivation {
    pname = "agent-browser-daemon";
    version = versions.agentBrowser;

    inherit src;

    nativeBuildInputs = [
      pkgs.nodejs
      pkgs.pnpm_9.configHook
      pkgs.nodePackages.typescript
    ];

    inherit pnpmDeps;

    env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";

    buildPhase = ''
      runHook preBuild
      tsc
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/agent-browser
      cp -r dist bin node_modules package.json $out/lib/agent-browser/
      runHook postInstall
    '';
  };

  cli = pkgs.rustPlatform.buildRustPackage {
    pname = "agent-browser-cli";
    version = versions.agentBrowser;

    inherit src;

    # cargoRoot tells cargoSetupHook where to find Cargo.lock relative to sourceRoot
    cargoRoot = "cli";
    # buildAndTestSubdir tells cargoBuildHook to pushd into cli/ before running cargo build
    buildAndTestSubdir = "cli";
    cargoHash = versions.agentBrowserCargoHash;

    buildType = "release";

    meta = {
      description = "Fast browser automation CLI for AI agents";
      mainProgram = "agent-browser";
    };
  };

  package = pkgs.stdenv.mkDerivation {
    pname = "agent-browser";
    version = versions.agentBrowser;
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      mkdir -p $out/bin $out/lib/agent-browser
      cp -r ${daemon}/lib/agent-browser/* $out/lib/agent-browser/

      makeWrapper ${cli}/bin/agent-browser $out/bin/agent-browser \
        --set AGENT_BROWSER_HOME "$out/lib/agent-browser" \
        --set AGENT_BROWSER_EXECUTABLE_PATH "${pkgs.chromium}/bin/chromium" \
        --set PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD "1" \
        --set FONTCONFIG_FILE "${pkgs.fontconfig.out}/etc/fonts/fonts.conf" \
        --set FONTCONFIG_PATH "${pkgs.fontconfig.out}/etc/fonts" \
        --prefix PATH : "${pkgs.nodejs}/bin"
    '';

    meta = with lib; {
      description = "Browser automation CLI for AI agents";
      license = licenses.asl20;
      mainProgram = "agent-browser";
      platforms = platforms.linux;
    };
  };
in
{
  inherit package;
}
