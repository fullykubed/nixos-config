{ pkgs, ... }:
let
  jBinary = pkgs.bun2nix-cli.mkDerivation {
    pname = "j";
    version = "0.1.0";
    src = builtins.path {
      path = ./.;
      name = "j-cli-src";
      filter =
        path: type:
        let
          base = builtins.baseNameOf path;
        in
        base != ".git"
        && base != ".claude"
        && base != ".bun"
        && base != "node_modules"
        && base != "dist"
        && base != ".build"
        && type != "unknown";
    };
    bunDeps = pkgs.bun2nix-cli.fetchBunDeps {
      bunNix = ./bun.nix;
    };
    # Two-step build: bundle with Solid JSX plugin first, then compile.
    # bun2nix's default single-step (bun build --compile --bytecode) fails
    # because @opentui/core uses top-level await (incompatible with --bytecode,
    # see https://github.com/oven-sh/bun/issues/14412), and would also skip
    # the Solid JSX transform needed by the dashboard command.
    buildPhase = ''
      runHook preBuild
      bun scripts/build.ts
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 dist/j $out/bin/j
      runHook postInstall
    '';
  };

  jCli = pkgs.writeShellApplication {
    name = "j";
    runtimeInputs = [
      pkgs.openssl
      pkgs.croc
      pkgs.netcat-gnu
      pkgs.tailscale
      pkgs.openssh
    ];
    text = ''
      exec ${jBinary}/bin/j "$@"
    '';
  };
in
{
  environment.systemPackages = [ jCli ];
}
