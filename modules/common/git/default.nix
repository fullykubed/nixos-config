{
  config,
  lib,
  pkgs,
  ...
}:
let
  gitName = "Jack Langston";

  gitDefaultBranch = pkgs.writeShellScriptBin "git-default-branch" (
    builtins.readFile ./scripts/git-default-branch
  );

  gitWorktreePath = pkgs.writeShellScriptBin "git-worktree-path" (
    builtins.readFile ./scripts/git-worktree-path
  );

  gitCloneForWorktree = pkgs.writeShellScriptBin "git-clone-for-worktree" (
    builtins.readFile ./scripts/git-clone-for-worktree
  );

  allowedSignersPath = "${config.homeDir}/.config/git/allowed_signers";
  githubPublicKey =
    let
      parts = builtins.filter builtins.isString (
        builtins.split " " (lib.removeSuffix "\n" (builtins.readFile ../../../secrets/git-ssh-key.pub))
      );
    in
    "${builtins.elemAt parts 0} ${builtins.elemAt parts 1}";
  githubEmail = "github@fullstackjack.io";
  githubHudsonPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBaDvNVFagHSDhKZrE4kH2U6+ynDNr9WXVeDdvSE7Jwp";
  githubHudsonEmail = "jack.langston@hudsonts.com";

  getKeyPath =
    name: "${config.homeDir}/${config.home-manager.users.${config.username}.home.file.${name}.target}";
in
{
  imports = [
    ./lazygit
    ./lazyworktree
  ];

  age.secrets.git-ssh-key = {
    rekeyFile = ../../../secrets/git-ssh-key.age;
    mode = "0400";
    owner = config.username;
  };

  home-manager.users.${config.username} = {

    programs.ssh.matchBlocks."github.com" = {
      identityFile = getKeyPath "githubPublicKey";
      identitiesOnly = true;
    };

    systemd.user.services.ssh-add-github = {
      Unit = {
        Description = "Load GitHub SSH key into agent";
        After = [ "ssh-agent.service" ];
        Requires = [ "ssh-agent.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.openssh}/bin/ssh-add ${config.age.secrets.git-ssh-key.path}";
        Environment = "SSH_AUTH_SOCK=%t/ssh-agent";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    xdg.configFile."git/allowed_signers".text = ''
      ${githubEmail} ${githubPublicKey}
      ${githubHudsonEmail} ${githubHudsonPublicKey}
    '';

    home.file = {
      githubPublicKey = {
        enable = true;
        text = githubPublicKey;
        target = ".ssh/github.pub";
      };
      githubHudsonPublicKey = {
        enable = true;
        text = githubHudsonPublicKey;
        target = ".ssh/github_hudson.pub";
      };
    };

    home.packages = with pkgs; [
      gh # Official GitHub CLI
      hub # Tool for interacting with Github API
      git-credential-manager # Tool for securely storing git credentials
      gitDefaultBranch # Output the remote default branch name
      gitWorktreePath # Output a branch's worktree path
      gitCloneForWorktree # Clone repos for worktree workflows
      mergiraf # Syntax-aware git merge driver
    ];

    programs = {
      zsh.shellAliases = {
        gs = "git status"; # [G]it [S]tatus
        gc = "git-clone-for-worktree";
        gca = "ai-commit"; # [G]it [C]ommit [A]I
        gls = "eza -l --git --no-user --follow-symlinks -o --no-permissions --time-style relative -F"; # [G]it [L]i[S]t
        grb = "ai-rebase"; # [G]it [R]e[B]ase via Claude Code
        gwls = "git worktree list"; # [G]it [W]orktree [L]i[S]t
      };

      difftastic = {
        enable = true;
        git.enable = true;
      };

      git = {
        enable = true;
        lfs.enable = true;

        ignores = [
          ".claude/prds/" # Ignore Claude Code PRD files in all repos
          ".claude/tmp/" # Ignore Claude Code temp scripts in all repos
          ".claude/settings.local.json" # Ignore local Claude Code settings
        ];

        # Use mergiraf for syntax-aware merge conflict resolution
        attributes = [
          "* merge=mergiraf"
        ];

        settings.alias = {
          fpush = "push --force-with-lease"; # Safe version of force-push
          lg = "!git log --color=always --no-show-signature --graph --abbrev-commit --decorate --date=relative --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim cyan)- %an%C(reset) %G?%C(bold yellow)%d%C(reset)' --all | sed -e 's/ G\\x1b/ ✅\\x1b/g' -e 's/ N\\x1b/ \\x1b/g' -e 's/ B\\x1b/ ❌\\x1b/g' -e 's/ U\\x1b/ ⚠️\\x1b/g' -e 's/ E\\x1b/ ❓\\x1b/g' | $PAGER";
        };

        includes = [
          # Default Settings
          {
            contents = {

              credential = {
                helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
                credentialStore = "secretservice";
              };

              core = {
                sshCommand = "ssh -o IdentitiesOnly=yes -i ${getKeyPath "githubPublicKey"}";
                # Prevent line endings issues
                autocrlf = "input";
                safecrlf = true;
              };

              pull = {
                rebase = true; # Only rebase on pulls
              };

              merge = {
                conflictstyle = "zdiff3"; # Show the original code in conflicts
                mergiraf = {
                  name = "mergiraf";
                  driver = "mergiraf merge --git %O %A %B -s %S -x %X -y %Y -p %P -l %L";
                };
              };

              commit = {
                gpgsign = true;
              };

              rebase = {
                autosquash = true; # allows fixup commits
                autostash = true; # automatically stash and pop on rebase
                updateRefs = true; # for rebasing stacked branches
              };

              push = {
                default = "current"; # automatically setup remote branches
                followtags = true; # automatically push tags
              };

              remote = {
                origin = {
                  tagopt = "--tags"; # Automatically fetch tags from remote
                };
              };

              rerere = {
                enabled = true; # automatically resolve conflicts more intelligently
              };

              help = {
                autocorrect = "prompt"; # automatically run fixed commands
              };

              diff = {
                algorithm = "histogram"; # Better diffs on file reordering
              };

              init = {
                defaultBranch = "main"; # align with Github conventions
              };

              log = {
                date = "iso-local"; # Better date prints
                showSignature = true; # Show git signatures
              };

              # Do some additional checks to prevent file corruption
              transfer.fsckobjects = true;
              fetch.fsckobjects = true;
              receive.fsckObjects = true;

              fetch = {

                # Automatically remove branches and tags that have been
                # remove upstream
                prune = true;
                prunetags = true;
              };

              gpg = {
                format = "ssh"; # Use ssh signing
                ssh = {
                  allowedSignersFile = allowedSignersPath;
                };
              };

              user = {
                name = gitName;
                email = githubEmail;
                signingKey = "key::${githubPublicKey}";
              };

              advice = {
                statusHints = false; # Disables parenthetical hints in git status
                resolveConflict = false;
                pushUpdateRejected = false; # Disables all push-related hints
                addEmptyPathspec = false;
                detachedHead = false;
                sequencerInUse = false;
                mergeConflict = false;
              };

              column = {
                ui = "auto"; # Will try to break long lists into columns
              };

              branch = {
                sort = "-committerdate"; # Sort branches by when they were last updated
              };

              tag = {
                sort = "taggerdate"; # Sort tags by the date when they were updated
              };
            };
          }

          ###########################################################
          # Overrides for specific directories
          ###########################################################
          {
            condition = "gitdir:${config.homeDir}/repos/panfactum/clients/hudsonts/";
            contents = {
              user = {
                name = gitName;
                email = githubHudsonEmail;
                signingKey = "key::${githubHudsonPublicKey}";
              };
              core = {
                sshCommand = "ssh -o IdentitiesOnly=yes -i ${getKeyPath "githubHudsonPublicKey"}";
              };
            };
          }
        ];
      };
    };
  };
}
