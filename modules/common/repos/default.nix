{
  config,
  lib,
  pkgs,
  ...
}:
let
  yamlFormat = pkgs.formats.yaml { };

  repoType = lib.types.submodule {
    options = {
      url = lib.mkOption {
        type = lib.types.str;
        description = "SSH clone URL";
      };
      path = lib.mkOption {
        type = lib.types.str;
        description = "Directory name under ~/repos/";
      };
      branch = lib.mkOption {
        type = lib.types.str;
        description = "Default branch to create a worktree for";
      };
      files = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Files placed in the branch worktree directory and excluded from git";
      };
      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Key-value pairs written to .env in the branch directory. Values can be literal strings or agenix secret paths (read at activation time).";
      };
      tmuxSession = lib.mkOption {
        type = lib.types.str;
        description = "Name of the detached tmux session for this repo";
      };
      direnv = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to run direnv allow as a workmux post_create hook";
      };
      workmuxConfig = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Additional workmux config deep-merged with {main_branch = branch}";
      };
    };
  };

  inherit (config) repos;
  reposBase = "${config.homeDir}/repos";

  repoSyncActivate = pkgs.writeShellScriptBin "repo-sync-activate" (
    builtins.readFile ./scripts/repo-sync-activate
  );

  repoSyncFetch = pkgs.writeShellScriptBin "repo-sync-fetch" (
    builtins.readFile ./scripts/repo-sync-fetch
  );

  repoSyncCleanup = pkgs.writeShellScriptBin "repo-sync-cleanup" (
    builtins.readFile ./scripts/repo-sync-cleanup
  );

  currentRepoNames = pkgs.writeText "repo-sync-current.json" (
    builtins.toJSON (builtins.attrNames repos)
  );

  # Per-repo JSON manifests for the activation script
  perRepoManifests = lib.mapAttrs (
    name: repo:
    pkgs.writeText "repo-sync-${name}.json" (
      builtins.toJSON {
        inherit name;
        inherit (repo)
          url
          path
          branch
          tmuxSession
          env
          files
          ;
      }
    )
  ) repos;

  # .envrc at repo root — sets GIT_DIR/GIT_WORK_TREE for the default branch
  envrcFiles = lib.mapAttrs' (
    _: repo:
    lib.nameValuePair "repos/${repo.path}/.envrc" {
      text = ''
        # Only set GIT env vars when loaded directly, not via source_up
        if [[ "$PWD" == "${reposBase}/${repo.path}" ]]; then
          export GIT_DIR="$PWD/.bare/worktrees/${repo.branch}"
          export GIT_WORK_TREE="$PWD/${repo.branch}"
        fi
      '';
    }
  ) repos;

  # Whitelist repo .envrc paths so direnv trusts them without manual approval
  direnvWhitelist = lib.mapAttrsToList (_: repo: "${reposBase}/${repo.path}/.envrc") repos;

  # .workmux.yaml in the default branch directory
  workmuxFiles = lib.mapAttrs' (
    _: repo:
    let
      direnvHooks = lib.optional repo.direnv "direnv allow";
      userHooks = repo.workmuxConfig.post_create or [ ];
      postCreate = direnvHooks ++ userHooks;
      direnvCopies = lib.optional repo.direnv ".envrc";
      envCopies = lib.optional (repo.env != { }) ".env";
      fileCopies =
        builtins.attrNames repo.files
        ++ direnvCopies
        ++ envCopies
        ++ (repo.workmuxConfig.files.copy or [ ]);
      baseConfig = lib.recursiveUpdate { main_branch = repo.branch; } (
        builtins.removeAttrs repo.workmuxConfig [
          "post_create"
          "files"
        ]
      );
      filesConfig =
        let
          userFiles = builtins.removeAttrs (repo.workmuxConfig.files or { }) [ "copy" ];
        in
        userFiles // lib.optionalAttrs (fileCopies != [ ]) { copy = fileCopies; };
      mergedConfig =
        baseConfig
        // lib.optionalAttrs (postCreate != [ ]) { post_create = postCreate; }
        // lib.optionalAttrs (filesConfig != { }) { files = filesConfig; };
    in
    lib.nameValuePair "repos/${repo.path}/${repo.branch}/.workmux.yaml" {
      source = yamlFormat.generate "workmux.yaml" mergedConfig;
    }
  ) repos;

  # Declared files in the branch worktree directory
  declaredFiles =
    let
      perRepo = lib.mapAttrsToList (
        _: repo:
        lib.mapAttrs' (
          fileName: content:
          lib.nameValuePair "repos/${repo.path}/${repo.branch}/${fileName}" {
            text = content;
          }
        ) repo.files
      ) repos;
    in
    builtins.foldl' (a: b: a // b) { } perRepo;

  # Per-repo activation entries
  perRepoActivations = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "repoSync-${name}" {
      after = [ "writeBoundary" ];
      before = [ "linkGeneration" ];
      data = ''
        export PATH="${pkgs.jq}/bin:${pkgs.git}/bin:$PATH"
        ${repoSyncActivate}/bin/repo-sync-activate "${perRepoManifests.${name}}" "${reposBase}" "${config.username}" || echo "repo-sync: WARNING: activation failed for ${name}" >&2
      '';
    }
  ) repos;

  # Per-repo fetch services
  perRepoFetchServices = lib.mapAttrs' (
    name: repo:
    lib.nameValuePair "repo-sync-fetch-${name}" {
      Unit = {
        Description = "Fetch ${name} repository";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${repoSyncFetch}/bin/repo-sync-fetch ${reposBase}/${repo.path}/.bare";
        Environment = [
          "PATH=${
            lib.makeBinPath [
              pkgs.git
              pkgs.openssh
            ]
          }"
          "GIT_SSH_COMMAND=\"ssh -i ${config.age.secrets.git-ssh-key.path} -o IdentitiesOnly=yes\""
        ];
      };
    }
  ) repos;

  # Per-repo fetch timers
  perRepoFetchTimers = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "repo-sync-fetch-${name}" {
      Unit = {
        Description = "Periodically fetch ${name} repository";
      };
      Timer = {
        OnStartupSec = "5min";
        OnUnitActiveSec = "30min";
        Unit = "repo-sync-fetch-${name}.service";
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    }
  ) repos;
in
{
  imports = [ ./configuration.nix ];

  options.repos = lib.mkOption {
    type = lib.types.attrsOf repoType;
    default = { };
    description = "Declaratively managed git repositories";
  };

  config = {
    home-manager.users.${config.username} = {
      home = {
        file = envrcFiles // workmuxFiles // declaredFiles;
        activation = perRepoActivations // {
          repoSyncCleanup = {
            after = [ "writeBoundary" ];
            before = [ "linkGeneration" ];
            data = ''
              export PATH="${pkgs.jq}/bin:$PATH"
              ${repoSyncCleanup}/bin/repo-sync-cleanup "${currentRepoNames}" "${config.homeDir}/.local/state/repo-sync"
            '';
          };
        };
      };

      programs.direnv.config.whitelist.exact = direnvWhitelist;

      systemd.user.services = perRepoFetchServices;
      systemd.user.timers = perRepoFetchTimers;
    };
  };
}
