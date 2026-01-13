{
  config,
  pkgs,
  ...
}:
{
  home-manager.users.${config.username} = {

    home.packages = with pkgs; [
      neovim-remote # For lazygit nvim-remote integration (avoids nested nvim issues)
      delta # Syntax-highlighting pager for git diffs
    ];

    programs.lazygit = {
      enable = true;
      package = pkgs.unstable.lazygit;
      settings = {
        git = {
          commitPrefix = [ ];
          commit = {
            signOff = true;
            autoWrapCommitMessage = true;
            autoWrapWidth = 72;
          };
          skipHookPrefix = "WIP";
          parseEmoji = true;
          pagers = [
            {
              colorArg = "always";
              pager = "delta --paging=never --line-numbers --hyperlinks";
            }
          ];
        };
        gui = {
          nerdFontsVersion = "3";
        };
        update = {
          days = 1;
        };
        os = {
          copyToClipboardCmd = "wl-copy {{text}}";
          readFromClipboardCmd = "wl-paste";
          edit = "nvr --remote-tab-wait-silent {{filename}}";
          editAtLine = "nvr --remote-tab-wait-silent +{{line}} {{filename}}";
          editAtLineAndWait = "nvr --remote-tab-wait-silent +{{line}} {{filename}}";
          editInTerminal = false;
        };
        keybinding = {
          universal = {
            quit = "<esc>";
            quit-alt1 = "q";
          };
        };
        customCommands = [
          {
            key = "C";
            description = "commit without hooks";
            context = "files";
            prompts = [
              {
                type = "input";
                title = "Commit message";
                key = "CommitMessage";
              }
            ];
            command = ''git -c core.hooksPath=/dev/null commit -m "{{.Form.CommitMessage}}"'';
            loadingText = "committing without hooks...";
          }
          {
            key = "<c-a>";
            description = "Generate commit message with AI";
            context = "files";
            command = "ai-commit";
            output = "terminal";
            loadingText = "Generating AI commit message...";
          }
          {
            key = "<c-a>";
            description = "Rewrite commit message with AI";
            context = "commits";
            command = "ai-reword {{.SelectedCommit.Hash}}";
            output = "terminal";
            loadingText = "Generating AI commit message...";
          }
        ];
      };
    };

    programs.zsh.shellAliases = {
      lg = "lazygit";
    };

  };
}
