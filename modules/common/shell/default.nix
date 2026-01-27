{ config, pkgs, ... }:
{
  # Enable zsh system-wide
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    kitty # terminal

    bat # "Better" cat
    eza # "Better" ls written in rust
    dut # Extremely performant disk usage analyzer
    ripgrep # "Better" grep written in rust
    fd # "Better" find written in rust
    fzf # For fuzzy finding
    killall # Kills all processes in tree
    pv # Stream monitoring
  ];

  home-manager.users.${config.username} = {
    ####################################
    ## Aliases
    ####################################
    home.shellAliases = {

      # For replacing grep with rg
      grep = "rg -uu";
      g = "rg -uu";

      # Listing aliases
      l = "eza -l --follow-symlinks -o --no-permissions --time-style iso -F"; # [L]ist files
      lt = "eza -l --follow-symlinks -o --no-permissions --time-style iso -F -T -L 2"; # [L]ist [T]ree (limited)
      ltt = "eza -l --follow-symlinks -o --no-permissions --time-style iso -F -T"; # [L]ist [T]ree (full)
      lu = "dut -d 1"; # [L]ist [U]sage
      luu = "dut"; # [L] [U]sage (full)

      # Finding aliases
      f = "fd -H --follow --exclude node_modules --exclude .direnv -X bat -r :10 --paging=never -S --squeeze-blank --wrap=never";
      fh = "fd -H --follow --base-directory $HOME --exclude node_modules --exclude .direnv --exclude .local --exclude .containers --exclude .steam --exclude .wine --exclude .nix-defexpr --exclude .bun --exclude .cache --exclude .npm --exclude go/pkg";
      fa = "fd -H --follow --base-directory / --exclude node_modules --exclude .direnv --exclude .local --exclude .containers --exclude .steam --exclude .wine --exclude .nix-defexpr --exclude .bun --exclude .cache --exclude .npm --exclude go/pkg";

      # [O]pen
      o = "xdg-open"; # Opens a file using the preferred application

      cat = "bat --no-pager";

      cd = "z";
    };

    ####################################
    ## Session Variables
    ####################################
    home.sessionVariables = {

      # Set the repo directories for use in dynamic repo scripts
      REPOS = "$HOME/repos";

      # Standard temporary directories (must be absolute paths)
      TMP = "/tmp";
      TMPDIR = "/tmp";

      # Use nvim as pager
      PAGER = "nvim -R";
      MANPAGER = "nvim +Man!";
    };

    ####################################
    ## GPG Agent
    ####################################
    services.gpg-agent = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      pinentry.package = pkgs.pinentry-gnome3;
    };

    programs = {
      ################################
      ##  Wezterm Terminal Configuration
      ################################
      wezterm = {
        enable = true;
        enableZshIntegration = true;
        extraConfig = ''
          local wezterm = require("wezterm")
          return {
            default_prog = { "${pkgs.zsh}/bin/zsh" },
            enable_tab_bar = false,
            enable_wayland = true,
            warn_about_missing_glyphs = false,
            -- Disable Alt+Enter fullscreen toggle so it passes through to tmux for popup
            keys = {
              {
                key = "Enter",
                mods = "ALT",
                action = wezterm.action.DisableDefaultAssignment,
              },
            },
          }
        '';
      };

      ################################
      ##  Startup - Terminal Formatting
      ################################
      starship = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        settings = {
          format = "$username$hostname$directory$git_branch$git_state$git_status$cmd_duration$line_break$character";
          directory = {
            style = "bold 33";
          };
          character = {
            success_symbol = "[❯](purple)";
            error_symbol = "[❯](red)";
          };
          git_branch = {
            format = "[$branch]($style)";
            style = "34";
          };
          git_status = {
            format = "[[(:$conflicted$untracked$modified$staged$renamed$deleted)](#cbffbe) ($ahead_behind$stashed)]($style)";
            conflicted = "X";
            untracked = "U";
            modified = "M";
            staged = "S";
            renamed = "R";
            deleted = "D";
            stashed = "^";
          };
          git_state = {
            format = "([$state( $progress_current/$progress_total)]($style)) ";
            style = "bright-black";
          };
          cmd_duration = {
            format = "[$duration]($style) ";
            style = "white";
          };
        };
      };

      ####################################
      ## Shell History - Atuin
      ####################################
      atuin = {
        enable = true;
        daemon.enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        flags = [
          "--disable-up-arrow"
        ];
        settings = {
          enter_accept = true;
          workspaces = true;
          update_check = false;
          auto_sync = false;
        };
      };

      ####################################
      ## Autojump - Zoxide
      ####################################
      zoxide = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
      };

      ####################################
      ## Fuzzy Finder - FZF
      ####################################
      fzf = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
      };

      ####################################
      ## Shell Completion - Carapace
      ####################################
      carapace = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
      };

      ####################################
      ## Better ls - Eza
      ####################################
      eza = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
      };

      ####################################
      ## Bash Config
      ####################################
      bash = {
        enable = true;
      };

      ####################################
      ## Zsh Config
      ####################################
      zsh = {
        enable = true;
        enableCompletion = false; # Carapace handles completions
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        oh-my-zsh = {
          enable = true;
          plugins = [
            "alias-finder"
            "colored-man-pages"
            "fancy-ctrl-z"
          ];
        };
      };

      ####################################
      ## Command Not Found
      ####################################
      command-not-found.enable = true;
    };
  };
}
