# Development shell, formatter, and pre-commit checks.
#
# prek is pinned to the Nix-provided version built from ./lib/packages/prek.nix
# rather than coming from the flake-pinned nixpkgs (which only ships prek
# 0.2.17, pre-dating the `priority` field). We also hand-generate the
# .pre-commit-config.yaml (as JSON) from Nix via `pkgs.formats.yaml` and
# install it via the shellHook, mirroring the Panfactum/stack pattern. This
# deliberately bypasses `cachix/git-hooks.nix`'s own run/checks derivation —
# we want `nix flake check` to stay fast and sandbox-clean, and the hooks to
# run at commit time (shellHook) and at Claude Stop time (separate script),
# not inside the Nix build sandbox where the bun-based hooks can't fetch deps.
{
  nixpkgs,
  nixpkgs-unstable,
  agenix-rekey,
  bun2nix,
  ...
}:
system:
let
  pkgs = import nixpkgs {
    inherit system;
    overlays = [
      agenix-rekey.overlays.default
      # Expose bun2nix's CLI as `pkgs.bun2nix-cli` so the proxy derivation
      # and the devshell can both find it. Mirrors the same overlay added
      # in lib/mk-nixos-system.nix for system builds.
      (_: _: { bun2nix-cli = bun2nix.packages.${system}.default; })
    ];
  };
  inherit (pkgs) lib;
  # prek is built from a local 0.3.8 derivation against nixpkgs-unstable
  # (rustc 1.92 is required and stable nixpkgs is still on 1.91.1). Stable
  # nixpkgs ships prek 0.2.17 which pre-dates the `priority` field; the
  # unstable channel ships 0.3.0; neither understands every field we use.
  # No overlay — nothing else in this module references `pkgs.prek`.
  prek = (import nixpkgs-unstable { inherit system; }).callPackage ../packages/prek.nix { };
  hcloud-upload-image = pkgs.callPackage ../packages/hcloud-upload-image.nix { };
  nixfmt = pkgs.treefmt.withConfig {
    runtimeInputs = [ pkgs.nixfmt-rfc-style ];

    settings = {
      # Log level for files treefmt won't format
      on-unmatched = "info";

      # Configure nixfmt for .nix files
      formatter.nixfmt = {
        command = "nixfmt";
        includes = [ "*.nix" ];
      };
    };
  };
  # check-package-json: walks every package.json in the repo, fails on any
  # unpinned (^/~/>=/latest) dep and any cross-package version mismatch.
  # The TypeScript implementation mirrors panfactum/stack/precommit-check-package-json.ts.
  checkPackageJson = pkgs.writeShellApplication {
    name = "check-package-json";
    runtimeInputs = [ pkgs.bun ];
    text = ''
      exec bun run ${./check-package-json.ts}
    '';
  };
  listMachines = pkgs.writeShellApplication {
    name = "list-machines";
    runtimeInputs = [ pkgs.jaq ];
    text = builtins.readFile ./list-machines.sh;
  };
  flashInstaller = pkgs.writeShellApplication {
    name = "flash-installer";
    runtimeInputs = [
      pkgs.jaq
      pkgs.util-linux
      pkgs.openssl
      pkgs.rage
      pkgs.pv
      pkgs.dosfstools
      listMachines
    ];
    text = builtins.readFile ./flash-installer.sh;
  };
  generateHostKey = pkgs.writeShellApplication {
    name = "generate-host-key";
    runtimeInputs = [
      pkgs.jaq
      pkgs.rage
      pkgs.openssh
      pkgs.agenix-rekey
      listMachines
    ];
    text = builtins.readFile ./generate-host-key.sh;
  };
  updateHostKey = pkgs.writeShellApplication {
    name = "update-host-key";
    runtimeInputs = [
      pkgs.rage
      pkgs.hostname
    ];
    text = builtins.readFile ./update-host-key.sh;
  };
  createSecret = pkgs.writeShellApplication {
    name = "create-secret";
    runtimeInputs = [
      pkgs.rage
      pkgs.gnugrep
      pkgs.agenix-rekey
    ];
    text = builtins.readFile ./create-secret.sh;
  };
  generateSyncthingKey = pkgs.writeShellApplication {
    name = "generate-syncthing-key";
    runtimeInputs = [
      pkgs.syncthing
      pkgs.jaq
      pkgs.rage
      pkgs.gnugrep
      pkgs.agenix-rekey
      listMachines
    ];
    text = builtins.readFile ./generate-syncthing-key.sh;
  };
  ntScripts =
    builtins.map
      (
        name:
        pkgs.writeShellApplication {
          inherit name;
          text = builtins.readFile (./. + "/${name}.sh");
        }
      )
      [
        "nt-syntax"
        "nt-eval"
        "nt-dry"
        "nt-pkg"
        "nt-option"
        "nt-build"
        "nt-check"
        "nt-hosts"
      ];
  # Per-project bun TypeScript projects. Each entry produces three prek hooks
  # (typecheck-${name}, lint-${name}, test-${name}) scoped via `files:` regex to that
  # project's directory. Each project is a self-contained bun package with
  # its own bun.lock + node_modules; the hooks below `bun install` lazily
  # in the project directory on first run. Add new projects here as the
  # repo grows.
  bunProjects = [
    {
      name = "proxy";
      dir = "modules/common/mitmproxy-credential-proxy/proxy";
    }
    {
      name = "cli";
      dir = "modules/common/cli";
    }
  ];

  # Lazily install a directory's bun deps if its node_modules is missing.
  # Used by both typecheck and lint hooks below.
  ensureBunInstalled = relDir: ''
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    if [[ ! -d "$REPO_ROOT/${relDir}/node_modules" ]]; then
      (cd "$REPO_ROOT/${relDir}" && bun install --frozen-lockfile) >&2
    fi
  '';

  # Per-project typecheck: ensure the project's deps are installed, then
  # cd into the project and run `tsc --noEmit` against its tsconfig.json.
  mkBunTypecheck =
    project:
    pkgs.writeShellApplication {
      name = "check-bun-typecheck-${project.name}";
      runtimeInputs = [
        pkgs.bun
        pkgs.typescript
      ];
      text = ''
        ${ensureBunInstalled project.dir}
        cd "$REPO_ROOT/${project.dir}"
        bunx tsc --noEmit
      '';
    };

  # Per-project test: ensure the project's deps are installed, then
  # cd into the project and run `bun test`.
  mkBunTest =
    project:
    pkgs.writeShellApplication {
      name = "check-bun-test-${project.name}";
      runtimeInputs = [
        pkgs.bun
        pkgs.git
        pkgs.tmux
      ];
      text = ''
        ${ensureBunInstalled project.dir}
        cd "$REPO_ROOT/${project.dir}"
        bun run test --only-failures
      '';
    };

  # Per-project lint: ensure the project's deps are installed (eslint and
  # typescript-eslint live in the project's own package.json), then run eslint
  # from the project directory. prek passes filenames relative to the repo
  # root, so prefix each with $REPO_ROOT to make them absolute before cd-ing.
  mkBunLint =
    project:
    pkgs.writeShellApplication {
      name = "check-bun-lint-${project.name}";
      runtimeInputs = [ pkgs.bun ];
      text = ''
        ${ensureBunInstalled project.dir}
        cd "$REPO_ROOT/${project.dir}"
        bunx eslint --fix --no-warn-ignored "''${@/#/$REPO_ROOT/}"
      '';
    };

  # Per-project knip: ensure the project's deps are installed, then
  # cd into the project and run knip to detect unused exports, files,
  # and dependencies.
  mkBunKnip =
    project:
    pkgs.writeShellApplication {
      name = "check-bun-knip-${project.name}";
      runtimeInputs = [ pkgs.bun ];
      text = ''
        ${ensureBunInstalled project.dir}
        cd "$REPO_ROOT/${project.dir}"
        bun run knip --fix --allow-remove-files
      '';
    };

in
{
  formatter = nixfmt;
  devShell = pkgs.mkShell {
    packages = [
      nixfmt
      pkgs.agenix-rekey
      pkgs.age
      pkgs.gitleaks
      pkgs.nixfmt-rfc-style
      pkgs.statix
      pkgs.deadnix
      prek
      (pkgs.writeShellScriptBin "headscale" ''
        export HEADSCALE_CLI_ADDRESS="headscale.panfactumcf.com:443"
        export HEADSCALE_CLI_API_KEY
        HEADSCALE_CLI_API_KEY=$(cat /run/agenix/headscale-api-key)
        TMPCONF=$(mktemp --suffix=.yaml)
        trap 'rm -f "$TMPCONF"' EXIT
        exec ${pkgs.headscale}/bin/headscale -c "$TMPCONF" "$@"
      '')
      pkgs.hcloud
      hcloud-upload-image
      pkgs.bun
      pkgs.bun2nix-cli
      listMachines
      flashInstaller
      generateHostKey
      updateHostKey
      generateSyncthingKey
      createSecret
      checkPackageJson
    ]
    ++ ntScripts
    ++ builtins.concatMap (project: [
      (mkBunTypecheck project)
      (mkBunLint project)
      (mkBunKnip project)
      (mkBunTest project)
    ]) bunProjects;

    # Register prek as the git pre-commit hook and pre-warm `bun install`
    # in every bun project (the repo root + each `bunProjects` entry) so
    # the typecheck/lint hooks don't pay the install cost on first commit.
    # .pre-commit-config.yaml is committed directly to the repo; hook
    # entries use PATH-based binary names resolved from the devshell.
    # Each install runs under a per-name lock in the git common dir so
    # concurrent devshell entries (multiple terminals or worktrees) don't
    # race on bun's global cache or on the shared git hooks directory.
    # Defensive `core.hooksPath` unset mirrors the Panfactum pattern
    # (prevents a stray local override from shadowing the hook).
    shellHook = ''
      REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
      git config --unset-all --local core.hooksPath 2>/dev/null || true

      LOCK_DIR="$(cd "$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --show-toplevel)" && pwd)/devshell-locks"
      mkdir -p "$LOCK_DIR"

      # Each call site invokes this with `&`, so bash runs it in a
      # subshell; that's what scopes the EXIT/signal trap below to a
      # single invocation instead of the caller's shell. mkdir is atomic
      # on POSIX, so we don't need flock.
      run_install() {
        local name="$1"
        shift
        local lockdir="$LOCK_DIR/$name.lock"
        local pidfile="$lockdir/pid"
        local waited=0
        while ! mkdir "$lockdir" 2>/dev/null; do
          # Reap a stale lock left behind by a crashed previous devshell.
          if [ -f "$pidfile" ] && ! kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null; then
            rm -rf "$lockdir"
            continue
          fi
          sleep 0.2
          waited=$((waited + 1))
          if [ "$waited" -gt 1500 ]; then # ~5 minutes
            echo "[$name] lock held for >5min; forcing release and proceeding" >&2
            rm -rf "$lockdir"
            waited=0
          fi
        done
        # Release the lock on any exit path - normal return, error,
        # Ctrl-C, SIGTERM, SIGHUP - so we never leak a stale lock.
        trap 'rm -rf "$lockdir"' EXIT HUP INT TERM
        echo $$ >"$pidfile"
        local output
        if ! output=$("$@" 2>&1); then
          echo "[$name] failed:" >&2
          echo "$output" >&2
        fi
        rm -rf "$lockdir"
        trap - EXIT HUP INT TERM
      }

      bun_install_in() {
        cd "$1" && bun install --frozen-lockfile --silent
      }

      run_install prek prek install --quiet &
      ${lib.concatMapStringsSep "\n      " (
        p: ''run_install bun-${p.name} bun_install_in "$REPO_ROOT/${p.dir}" &''
      ) bunProjects}
      wait
    '';
  };
}
