{ pkgs, lib, ... }:
let
  bun2nix = pkgs.bun2nix-cli;
in
pkgs.stdenv.mkDerivation {
  pname = "llm-summarize";
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

    # NOTE: the bytecode flag is intentionally omitted. Bun issues #27955
    # and #27454 cause compile+bytecode+format=esm to produce broken
    # binaries with dangling module references. The ~5ms startup penalty
    # from omitting it is irrelevant for a hook that fires once per
    # Claude session end.
    bun build --compile \
      --minify \
      --sourcemap=none \
      --target=bun-linux-x64 \
      --outfile llm-summarize \
      src/main.ts

    runHook postBuild
  '';

  # The fixupPhase's strip pass strips ELF debug sections, which destroys
  # the JavaScript payload that `bun build --compile` embeds in those sections.
  # After stripping, the binary silently falls back to the raw Bun runtime
  # (showing `bun --help` instead of our code). Setting dontStrip prevents
  # this. patchelf --shrink-rpath is still safe and runs during fixupPhase.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # Install the compiled binary with a hidden name, then wrap it.
    # makeWrapper must receive an absolute path to the real binary so the
    # generated wrapper script uses `exec /nix/store/.../llm-summarize-unwrapped`
    # rather than the relative `./llm-summarize` (which would only work if the
    # caller's working directory happened to contain the binary).
    install -m 0755 ./llm-summarize $out/bin/.llm-summarize-unwrapped

    # Compiled Bun binaries don't inherit the OS CA store (Bun issue
    # #13868), so HTTPS fetch() to api.anthropic.com would fail TLS
    # verification. Setting the CA certs env var points Bun at the
    # NixOS-managed NSS root cert bundle so TLS works at runtime.
    makeWrapper $out/bin/.llm-summarize-unwrapped $out/bin/llm-summarize \
      --set NODE_EXTRA_CA_CERTS "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

    runHook postInstall
  '';

  meta = with lib; {
    description = "One-shot LLM text transformer calling the Anthropic Messages API";
    license = licenses.mit;
    mainProgram = "llm-summarize";
    platforms = platforms.linux;
  };
}
