{
  pkgs,
  lib,
  versions,
  ...
}:
let
  package = pkgs.rustPlatform.buildRustPackage {
    pname = "rtk";
    version = versions.rtk;

    src = pkgs.fetchFromGitHub {
      owner = "rtk-ai";
      repo = "rtk";
      rev = versions.rtkRev;
      hash = versions.rtkSrcHash;
    };

    cargoHash = versions.rtkCargoHash;

    meta = with pkgs.lib; {
      description = "CLI proxy that reduces LLM token consumption by 60-90%";
      homepage = "https://github.com/rtk-ai/rtk";
      license = licenses.mit;
      mainProgram = "rtk";
    };
  };

  wrappedCommands = [
    "git"
    "gh"
    "aws"
    "psql"
    "pnpm"
    "npm"
    "npx"
    "docker"
    "kubectl"
    "curl"
    "wget"
    "ls"
    "tree"
    "find"
    "diff"
    "grep"
    "wc"
    "cargo"
    "go"
    "ruff"
    "pytest"
    "mypy"
    "rake"
    "rubocop"
    "rspec"
    "pip"
    "vitest"
    "prisma"
    "tsc"
    "next"
    "prettier"
    "playwright"
    "dotnet"
    "lint"
  ];

  wrappers = pkgs.runCommand "rtk-wrappers" { } ''
    mkdir -p $out/bin
    ${lib.concatMapStringsSep "\n" (cmd: ''
            cat > $out/bin/${cmd} <<'WRAPPER'
      #!/bin/bash
      # RTK wrapper for ${cmd} -- strips wrapper dir to prevent loops
      export PATH="''${PATH//\/opt\/rtk\/bin:/}"
      export PATH="''${PATH%/opt/rtk/bin}"
      if [[ -n "''${NO_RTK:-}" ]]; then
        exec ${cmd} "$@"
      fi
      exec ${package}/bin/rtk ${cmd} "$@"
      WRAPPER
            chmod +x $out/bin/${cmd}
    '') wrappedCommands}
  '';
in
{
  inherit package wrappers;

  homeFiles = {
    ".config/rtk/config.toml" = {
      text = ''
        [telemetry]
        enabled = false

        [tracking]
        enabled = true
        history_days = 90

        [display]
        colors = false
        emoji = false

        [tee]
        enabled = true
        mode = "failures"
        max_files = 20
      '';
    };
  };
}
