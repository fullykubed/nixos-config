{
  config,
  pkgs,
  ...
}:
let
  workmux = pkgs.rustPlatform.buildRustPackage rec {
    pname = "workmux";
    version = "0.1.79";

    src = pkgs.fetchFromGitHub {
      owner = "raine";
      repo = "workmux";
      rev = "9289c5ae1f7c0f3e8548a0173858ad1265864f71";
      hash = "sha256-VZlrhjKnkzlokJmHlQErlMfpp69n0gisJpdJ1UUSVNw=";
    };

    cargoHash = "sha256-mjAdMNv4GbtWdKsTHaBNfvip/qORuMuS88plZohzM9o=";

    meta = with pkgs.lib; {
      description = "CLI tool combining git worktrees and tmux for parallel development";
      homepage = "https://github.com/raine/workmux";
      license = licenses.mit;
      mainProgram = "workmux";
    };
  };
in
{
  home-manager.users.${config.username} = {
    home.packages = with pkgs; [
      libnotify # Required for tmux-notify desktop notifications
      sesh # Session manager for tmux
      workmux # Git worktrees + tmux workflow tool
    ];

    programs.zsh.initContent = ''
      # Workmux completions
      eval "$(workmux completions zsh)"
    '';

    programs.zsh.shellAliases = {
      wm = "workmux";
    };

    xdg.configFile."workmux/config.yaml".text = ''
      # Global workmux configuration
      merge_strategy: rebase
      agent: claude
      worktree_naming: full
      worktree_dir: ../
      window_prefix: "\uf418 "

      post_create:
        - direnv allow

      files:
        copy:
          - .env
    '';

    # This launches tmux when the system boots so that
    # sessions are resurrected and immediately available
    systemd.user.services.tmux-start-server = {
      Unit = {
        Description = "Starts the tmux server";
        After = [ "default.target" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = "TMUX_TMPDIR=%t";
        ExecStart = "/run/current-system/sw/bin/zsh -lc 'tmux start-server'";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    programs.tmux = {
      enable = true;
      terminal = "wezterm";
      shell = "${pkgs.zsh}/bin/zsh";
      historyLimit = 10000;
      mouse = true;
      keyMode = "vi";
      baseIndex = 1;
      escapeTime = 0;
      clock24 = false;
      newSession = false;
      sensibleOnTop = true;
      secureSocket = true;
      customPaneNavigationAndResize = true;

      plugins = with pkgs.tmuxPlugins; [
        vim-tmux-navigator
        yank
        sensible
        tmux-fzf
        {
          plugin = resurrect;
          extraConfig = ''
            set -g @resurrect-capture-pane-contents 'on'
          '';
        }
        {
          plugin = dracula;
          extraConfig = ''
            set -g @dracula-show-powerline false
            set -g @dracula-show-left-icon session
            set -g @dracula-show-timezone false
            set -g @dracula-military-time false
            set -g @dracula-show-location false
            set -g @dracula-show-empty-plugins false
          '';
        }
        {
          plugin = mkTmuxPlugin {
            pluginName = "tmux-autoreload";
            version = "unstable-2024-01-01";
            rtpFilePath = "tmux-autoreload.tmux";
            src = pkgs.fetchFromGitHub {
              owner = "b0o";
              repo = "tmux-autoreload";
              rev = "e98aa3b74cfd5f2df2be2b5d4aa4ddcc843b2eba";
              sha256 = "sha256-9Rk+VJuDqgsjc+gwlhvX6uxUqpxVD1XJdQcsc5s4pU4=";
            };
          };
          extraConfig = ''
            set -g @tmux-autoreload-configs '$HOME/.config/tmux/tmux.conf'
            set -g @tmux-autoreload-quiet 0
          '';
        }
        {
          plugin = mkTmuxPlugin {
            pluginName = "tmux-notify";
            version = "unstable-2024-11-18";
            rtpFilePath = "tnotify.tmux";
            src = pkgs.fetchFromGitHub {
              owner = "rickstaa";
              repo = "tmux-notify";
              rev = "b713320af05837c3b44e4d51167ff3062dbeae4b";
              sha256 = "sha256-wOmq2stWXAFmYrRuIqf9IPATYXJ+OFoYXnJdHUnJQxY=";
            };
          };
          extraConfig = ''
            # Tmux-notify configuration
            set -g @tnotify-verbose 'on'
            set -g @tnotify-verbose-msg 'Command completed: #W'
            set -g @tnotify-threshold '10'
            set -g @tnotify-sleep-duration '2'
          '';
        }
        {
          plugin = continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
            set -g @continuum-save-interval '5'
          '';
        }
      ];

      extraConfig = ''
          # Set background color to base00 for inactive, base01 for active
          set -g window-style 'bg=${config.lib.stylix.colors.withHashtag.base00}'
          set -g window-active-style 'bg=${config.lib.stylix.colors.withHashtag.base01}'

          # Use Ctrl-a as prefix
          unbind C-b
          set -g prefix C-a
          bind C-a send-prefix

          # Split panes using | and -
          bind | split-window -h -c "#{pane_current_path}"
          bind - split-window -v -c "#{pane_current_path}"
          unbind '"'
          unbind %

          # Rename window and session
          bind r command-prompt -I "#W" "rename-window '%%'"
          bind R command-prompt -I "#S" "rename-session '%%'"

          # Reload config
          bind -n M-R source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"

          # Resize panes with vim keys
          bind -r h resize-pane -L 5
          bind -r j resize-pane -D 5
          bind -r k resize-pane -U 5
          bind -r l resize-pane -R 5

          # Move panes around (swap with direction)
          bind -n M-h swap-pane -d -t '{left-of}'
          bind -n M-j swap-pane -d -t '{down-of}'
          bind -n M-k swap-pane -d -t '{up-of}'
          bind -n M-l swap-pane -d -t '{right-of}'

          # Rotate panes
          bind -n M-r rotate-window
          bind -n M-e rotate-window -D

          # Maximize/zoom pane
          bind m resize-pane -Z

          # Custom master layout - main pane at top with 70% height
          bind -n M-m select-layout main-horizontal \; run-shell "tmux resize-pane -t 0 -y \$((\$(tmux display -p '#{window_height}') * 70 / 100))"

          # Window navigation
          bind -n M-n next-window
          bind -n M-p previous-window

          # Session navigation - show windows in tree view (expanded)
          bind s choose-tree -Z
          bind -n M-1 select-window -t 1
          bind -n M-2 select-window -t 2
          bind -n M-3 select-window -t 3
          bind -n M-4 select-window -t 4
          bind -n M-5 select-window -t 5
          bind -n M-6 select-window -t 6
          bind -n M-7 select-window -t 7
          bind -n M-8 select-window -t 8
          bind -n M-9 select-window -t 9

          # Create new window with current path
          bind c new-window -c "#{pane_current_path}"

          # Kill pane/window without confirmation
          bind -n M-x kill-pane
          bind -n M-X kill-window

          # Copy mode improvements
          bind Enter copy-mode
          bind -T copy-mode-vi v send-keys -X begin-selection
          bind -T copy-mode-vi C-v send-keys -X rectangle-toggle
          bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel
          bind -T copy-mode-vi Escape send-keys -X cancel

          # Copy to system clipboard (requires wl-copy for Wayland)
          bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'wl-copy'
          bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel 'wl-copy'

          # Status bar customization
          set -g status-position top
          set -g status-interval 5
          set -g status-justify left

          # Terminal overrides for wezterm with true color support
          set -g default-terminal "tmux-256color"
          set-option -sa terminal-features ''',wezterm:RGB'''
          set-option -ga terminal-features ",wezterm:usstyle"
          set-option -ga terminal-overrides ",*:Tc"

          # Enable focus events
          set -g focus-events on

          # Activity monitoring
          setw -g monitor-activity on
          set -g visual-activity off

          # Renumber windows when one is closed
          set -g renumber-windows on

          # Set parent terminal title to reflect current window
          set -g set-titles on
          set -g set-titles-string "#S / #W"

          # Message styling
          set -g message-style fg=${config.lib.stylix.colors.withHashtag.base00},bg=${config.lib.stylix.colors.withHashtag.base0D},bold

          # Copy mode selection color (match nvim visual selection)
          set -g mode-style fg=${config.lib.stylix.colors.withHashtag.base05},bg=${config.lib.stylix.colors.withHashtag.base03}

          # Pane border styling - no borders for panes, but visible borders for popups
          set -g pane-border-lines single
          set -g popup-border-lines rounded
          set -g pane-border-status off
          set -g pane-border-indicators off
          # Make pane borders invisible by setting colors to background
          set -g pane-border-style fg=default,bg=default
          set -g pane-active-border-style fg=default,bg=default
          # Keep popup borders visible
          set -g popup-border-style fg=${config.lib.stylix.colors.withHashtag.base0D},bg=default

          # Change the working directory of the session to the working directory of the current pane
          bind -n M-c attach-session -c "#{pane_current_path}"

          # Activate Mouse
          set -g mouse on
          bind -n WheelUpPane if -F '#{alternate_on}' 'send-keys Up' 'if -F "#{mouse_any_flag}" "send -M" "copy-mode -e; send-keys -M"'
          bind -n WheelDownPane if -F '#{alternate_on}' 'send-keys Down' 'send-keys -M'

        	# sesh settings
        	bind-key x kill-pane # skip "kill-pane 1? (y/n)" prompt
        	set -g detach-on-destroy off  # don't exit from tmux when closing a session
        	bind -n M-s run-shell "sesh connect \"$(
        		sesh list --tmux --icons | fzf-tmux -p 80%,70% \
        		    --no-sort --ansi --border-label ' sesh ' --prompt '⚡  ' \
        		    --header '  ^a all ^t tmux ^g configs ^x zoxide ^d tmux kill ^f find' \
        		    --bind 'tab:down,btab:up' \
        		    --bind 'ctrl-a:change-prompt(⚡  )+reload(sesh list --icons)' \
        		    --bind 'ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons)' \
        		    --bind 'ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)' \
        		    --bind 'ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)' \
        		    --bind 'ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~)' \
        		    --bind 'ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons)' \
        		    --preview-window 'right:55%' \
        		    --preview 'sesh preview {}'
        	)\""
          bind -n M-S run-shell "sesh last"

          # Workmux dashboard popup
          bind -n M-a display-popup -h 30 -w 100 -E "workmux dashboard"

          # Lazygit popup
          bind -n M-g display-popup -d "#{pane_current_path}" -h 90% -w 90% -E "lazygit"

          # Lazyworktree popup
          bind -n M-w display-popup -d "#{pane_current_path}" -h 90% -w 90% -E "lazyworktree"

          # Keybinding browser with fzf - shows all tmux keybindings and allows execution
          bind -n M-? run-shell "tmux list-keys -aN | \
            awk '{ \
              gsub(/^[[:space:]]+/, \"\", \$0); \
              original = \$0; \
              \
              if (index(\$1, \"C-a\") == 1) { \
                table = \"prefix\"; \
                actual_key = \$2; \
                pos = index(original, \$2); \
                if (pos > 0) { \
                  pos += length(\$2); \
                  desc_or_cmd = substr(original, pos); \
                } else { \
                  desc_or_cmd = \"\"; \
                } \
              } else { \
                table = \"root\"; \
                actual_key = \$1; \
                pos = index(original, \$1); \
                if (pos > 0) { \
                  pos += length(\$1); \
                  desc_or_cmd = substr(original, pos); \
                } else { \
                  desc_or_cmd = \"\"; \
                } \
              } \
              gsub(/^[[:space:]]+/, \"\", desc_or_cmd); \
              printf \"%-8s %-15s %s\\n\", table, actual_key, desc_or_cmd \
            }' | \
            fzf-tmux -p 90%,75% \
              --border-label ' tmux keybindings ' \
              --prompt '🔑  ' \
              --header 'Table    Key             Description/Command' \
              --preview 'echo {}' \
              --preview-window 'up:3:wrap' | \
            sh -c 'read table key rest; if [ \"\$table\" = \"prefix\" ] || [ \"\$table\" = \"root\" ]; then cmd=\$(tmux list-keys -T \"\$table\" \"\$key\" 2>/dev/null | cut -d\" \" -f5-); eval \"tmux \$cmd\"; fi'"
      '';
    };
  };
}
