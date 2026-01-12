#  Notes on SSH Keys
#
#  * All SSH private keys are stored in a keepass db and loaded to the ssh-agent when the keepass database
#    is opened (and removed when the keepass database closes).
#
#  * The public keys are still written to disk via this configuration so they can be used to specify the SSH key
#    to use on the directory-specific git setting.

{
  config,
  pkgs,
  ...
}:
let
  gitName = "Jack Langston";

  gitCloneForWorktree = pkgs.writeShellScriptBin "git-clone-for-worktree" (
    builtins.readFile ./scripts/git-clone-for-worktree
  );

  aiCommit = pkgs.writeShellScriptBin "ai-commit" (builtins.readFile ./scripts/ai-commit);

  aiReword = pkgs.writeShellScriptBin "ai-reword" (builtins.readFile ./scripts/ai-reword);

  gitRebaseClaude = pkgs.writeShellScriptBin "git-rebase-claude" (builtins.readFile ./scripts/git-rebase-claude);

  allowedSignersFile = "git/allowed_signers";
  githubPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAlCQ99fqK+ozVXBUCIhr8KY86XAtRjTKzTnM9UCaoI7";
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

  home-manager.users.${config.username} = {

    xdg.configFile = {
      allowedSigners = {
        enable = true;
        target = allowedSignersFile;
        text = ''
          ${githubEmail} ${githubPublicKey}
          ${githubHudsonEmail} ${githubHudsonPublicKey}
        '';
      };
    };

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
      hub # Tool for interacting with Github API
      git-credential-manager # Tool for securely storing git credentials
      gitCloneForWorktree # Clone repos for worktree workflows
      aiCommit # Generate commit messages with Claude AI
      aiReword # Rewrite commit messages with Claude AI
      gitRebaseClaude # Rebase with Claude Code conflict resolution
    ];

    programs.zsh.shellAliases = {
      gc = "git-clone-for-worktree";
      gls = "eza -l --git --no-user --follow-symlinks -o --no-permissions --time-style relative -F"; # [G]it [L]i[S]t
      grb = "git-rebase-claude"; # [G]it [R]e[B]ase via Claude Code
    };

    programs.difftastic = {
      enable = true;
      git.enable = true;
    };

    programs.git = {
      enable = true;
      lfs.enable = true;

      ignores = [
        ".claude/prds/" # Ignore Claude Code PRD files in all repos
        ".claude/settings.local.json" # Ignore local Claude Code settings
      ];

      settings.aliases = {
        fpush = "push --force-with-least"; # Safe version of force-push
        lg = "log --graph --abbrev-commit --decorate --date=relative --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all";
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
              # Prevent line endings issues
              autocrlf = "input";
              safecrlf = true;
            };

            pull = {
              rebase = true; # Only rebase on pulls
            };

            merge = {
              conflictstyle = "zdiff3"; # Show the original code in conflicts
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
                allowedSignersFile = "~/.config/${allowedSignersFile}";
              };
            };

            user = {
              name = gitName;
              email = githubEmail;
              signingKey = "key::${githubPublicKey}";
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
}
