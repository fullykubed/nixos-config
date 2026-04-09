# modules/common/claude/better-ccflare/default.nix
#
# better-ccflare: Claude API load-balancing proxy.
#
# === Version-bump procedure ===
# 1. Bump versions.betterCcflare in lib/versions.nix.
# 2. Get the new src hash:
#      nix-prefetch-github tombii better-ccflare --rev v<new>
#    and update versions.betterCcflareSrcHash.
# 3. Regenerate bun.nix from the pinned tag's bun.lock:
#      cd modules/common/claude/better-ccflare
#      curl -sL https://github.com/tombii/better-ccflare/archive/refs/tags/v<new>.tar.gz \
#        | tar -xz --strip-components=1 better-ccflare-<new>/bun.lock
#      bun2nix -o bun.nix   # regen ./bun.nix
#      rm bun.lock           # NOT vendored
# 4. Build and run the telemetry smoke test: nix build .#<attr>
# ================================
{
  pkgs,
  lib,
  versions,
  ...
}:
let
  bun2nix = pkgs.bun2nix-cli;

  package = pkgs.stdenv.mkDerivation {
    pname = "better-ccflare";
    version = versions.betterCcflare;

    src = pkgs.fetchFromGitHub {
      owner = "tombii";
      repo = "better-ccflare";
      tag = "v${versions.betterCcflare}";
      hash = versions.betterCcflareSrcHash;
    };

    nativeBuildInputs = [
      pkgs.bun
      pkgs.nodejs
      pkgs.makeWrapper
      bun2nix.hook
    ];

    # Pre-fetched Bun dependencies (no network needed during build)
    bunDeps = bun2nix.fetchBunDeps {
      bunNix = ./bun.nix;
    };

    # Override bun2nix's default `--linker=isolated`. better-ccflare's monorepo
    # build script imports workspace packages by sub-path (e.g.
    # `@better-ccflare/providers/bedrock`, `@better-ccflare/http-common/symbols`),
    # which relies on bun's hoisted layout where workspace packages are
    # symlinked into the root `node_modules/@better-ccflare/*`. With isolated
    # linking, workspace packages land in per-workspace `node_modules` only and
    # sub-path resolution from sibling workspaces breaks.
    #
    # Pass as a string (not a Nix list) so mkDerivation doesn't stringify a
    # list into a scalar that concatTo warns about ("not declared as array").
    bunInstallFlags = "--linker=hoisted";

    dontStrip = true;

    preBuild = ''
      # The `bun` npm package ships with a placeholder binary that its
      # postinstall script normally replaces by downloading the real bun
      # binary from npm. bun2nix runs the initial install with
      # `--ignore-scripts`, and the followup lifecycle phase doesn't re-run
      # postinstalls for already-installed packages. The placeholder then
      # refuses to execute ("Bun's postinstall script was not run"), which
      # breaks the monorepo build script since it invokes `bun build`
      # through `node_modules/.bin/bun`. Point both entry points at the
      # real system bun so the build can proceed hermetically.
      if [ -e node_modules/bun/bin/bun ]; then
        ln -sf ${pkgs.bun}/bin/bun node_modules/bun/bin/bun
      fi
      if [ -e node_modules/.bin/bun ]; then
        ln -sf ${pkgs.bun}/bin/bun node_modules/.bin/bun
      fi
    '';

    buildPhase = ''
      runHook preBuild

      cd apps/cli
      bun run build
      cd ../..

      runHook postBuild
    '';

    postBuild = ''
      # Defense in depth against upstream silently adding telemetry in a
      # version bump. If any of these hostnames appear in the compiled binary,
      # the build fails immediately so the derivation cannot be installed.
      bin=apps/cli/dist/better-ccflare
      for host in sentry.io posthog mixpanel segment.io honeycomb.io analytics.google.com; do
        if grep -a -q "$host" "$bin"; then
          echo "ERROR: telemetry host '$host' found in compiled better-ccflare binary" >&2
          exit 1
        fi
      done
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 apps/cli/dist/better-ccflare $out/bin/better-ccflare
      runHook postInstall
    '';

    meta = with lib; {
      description = "Claude API proxy with multi-account load balancing";
      homepage = "https://github.com/tombii/better-ccflare";
      license = licenses.mit;
      mainProgram = "better-ccflare";
      platforms = platforms.linux;
    };
  };
in
{
  inherit package;

  systemdServices = {
    better-ccflare = {
      Unit = {
        Description = "better-ccflare Claude API load balancer";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${package}/bin/better-ccflare";
        Restart = "on-failure";
        RestartSec = 5;
        Environment = [
          "PORT=8788"
          "BETTER_CCFLARE_HOST=127.0.0.1"
          "BETTER_CCFLARE_DB_PATH=%h/.local/share/better-ccflare/better-ccflare.db"
          "BETTER_CCFLARE_CONFIG_PATH=%h/.local/share/better-ccflare/config.json"
        ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
