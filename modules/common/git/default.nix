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

  gitCloneForWorktree = pkgs.writeShellScriptBin "git-clone-for-worktree" (builtins.readFile ./scripts/git-clone-for-worktree);

  lazyworktree = pkgs.buildGoModule rec {
    pname = "lazyworktree";
    version = "1.21.1";
    src = pkgs.fetchFromGitHub {
      owner = "chmouel";
      repo = "lazyworktree";
      rev = "v${version}";
      hash = "sha256-5ercx4htJ1GS7nGwK/BeIGrt4ZQLql4Z4pDTVTWZH8o=";
    };
    vendorHash = "sha256-0O8i84mzAYq/VUWn0vbHf218hwXRMAvlfKnBUYXo8Ck=";
    subPackages = [ "cmd/lazyworktree" ];
    meta = {
      description = "A lazygit-inspired TUI for git worktrees";
      homepage = "https://github.com/chmouel/lazyworktree";
      mainProgram = "lazyworktree";
    };
  };

  allowedSignersFile = "git/allowed_signers";
  githubPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAlCQ99fqK+ozVXBUCIhr8KY86XAtRjTKzTnM9UCaoI7";
  githubEmail = "github@fullstackjack.io";
  githubHudsonPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBaDvNVFagHSDhKZrE4kH2U6+ynDNr9WXVeDdvSE7Jwp";
  githubHudsonEmail = "jack.langston@hudsonts.com";

  getKeyPath =
    name: "${config.homeDir}/${config.home-manager.users.${config.username}.home.file.${name}.target}";
in
{
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

      lazygitConfig = {
        enable = true;
        target = "lazygit/config.yml";
        text = ''
          git:
            commitPrefix: []
            commit:
              signOff: true
              autoWrapCommitMessage: true
              autoWrapWidth: 72
            skipHookPrefix: "WIP"
            parseEmoji: true

          gui:
            nerdFontsVersion: "3"
            theme:
              selectedLineBgColor:
                - "#2d2d2d"
              selectedRangeBgColor:
                - "#2d2d2d"

          update:
            days: 1

          os:
            copyToClipboardCmd: "wl-copy {{text}}"
            readFromClipboardCmd: "wl-paste"

          keybinding:
            universal:
              quit: '<esc>'
              quit-alt1: 'q'

          customCommands:
            - key: 'C'
              description: 'commit without hooks'
              context: 'files'
              prompts:
                - type: 'input'
                  title: 'Commit message'
                  key: 'CommitMessage'
              command: 'git -c core.hooksPath=/dev/null commit -m "{{.Form.CommitMessage}}"'
              loadingText: 'committing without hooks...'
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
      unstable.lazygit # Terminal UI for git commands
      lazyworktree # TUI for git worktrees
      gitCloneForWorktree # Clone repos for worktree workflows
    ];

    programs.zsh.shellAliases = {
      gc = "git-clone-for-worktree";
      gls = "eza -l --git --no-user --follow-symlinks -o --no-permissions --time-style relative -F"; # [G]it [L]i[S]t
      lg = "lazygit";
      lw = "lazyworktree";
    };

    programs.difftastic = {
      enable = true;
      git.enable = true;
    };

    programs.git = {
      enable = true;
      lfs.enable = true;

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
