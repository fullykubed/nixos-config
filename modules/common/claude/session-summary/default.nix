{
  pkgs,
  lib,
  claude-code-sandboxed,
  ...
}:
let
  bun2nix = pkgs.bun2nix-cli;
in
pkgs.stdenv.mkDerivation {
  pname = "claude-session-summary";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [
    pkgs.bun
    pkgs.makeWrapper
    bun2nix.hook
  ];

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  buildPhase = ''
    runHook preBuild

    bun build --compile \
      --minify \
      --sourcemap=none \
      --target=bun-linux-x64 \
      --outfile claude-session-summary \
      src/main.ts

    runHook postBuild
  '';

  # dontStrip prevents the fixupPhase strip pass from destroying the JS
  # payload that bun build --compile embeds in ELF debug sections.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    install -m 0755 ./claude-session-summary $out/bin/.claude-session-summary-unwrapped

    makeWrapper $out/bin/.claude-session-summary-unwrapped $out/bin/claude-session-summary \
      --set NODE_EXTRA_CA_CERTS "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" \
      --set CLAUDE_BIN "${claude-code-sandboxed}/bin/claude" \
      --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.git ]}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Claude Code session summary pipeline CLI and hook";
    license = licenses.mit;
    mainProgram = "claude-session-summary";
    platforms = platforms.linux;
  };
}
