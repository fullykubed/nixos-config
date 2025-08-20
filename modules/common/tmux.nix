{
  config,
  pkgs,
  lib,
  ...
}:
{
  home-manager.users.${config.username} = {
    home.packages = with pkgs; [
      libnotify # Required for tmux-notify desktop notifications
    ];

    programs.tmux = {
      enable = true;
      terminal = "alacritty";
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
            set -g @resurrect-strategy-nvim 'session'
          '';
        }
        {
          plugin = continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
            set -g @continuum-save-interval '15'
          '';
        }
        {
          plugin = dracula;
          extraConfig = ''
            set -g @dracula-show-powerline true
            set -g @dracula-show-left-icon session
            set -g @dracula-plugins "continuum attached-clients"
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
      ];

      extraConfig = ''
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
        bind g source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"

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
        bind -n C-n next-window
        bind -n C-p previous-window

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
        bind x kill-pane
        bind X kill-window

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

        # Terminal overrides for alacritty with true color support
        set -g default-terminal "alacritty"
        set-option -sa terminal-features ''',alacritty:RGB'''
        set-option -ga terminal-features ",alacritty:usstyle"
        set-option -ga terminal-overrides ''',alacritty:Tc'''

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
        set -g message-style fg=colour232,bg=colour33,bold

        # Pane border styling - creates padding effect
        # Use thicker borders as visual padding between panes
        set -g pane-border-style fg=#2a2a2a,bg=#2a2a2a
        set -g pane-active-border-style fg=#000000,bg=#000000  # Black border for active pane
        set -g pane-border-lines heavy
        set -g popup-border-lines heavy
        set -g pane-border-status off
        set -g pane-border-indicators off

        # Set pane background colors using hooks
        # Active pane: pure black background, Inactive panes: lighter gray background
        # Use hooks to change pane style on focus events
        set-hook -g pane-focus-in 'select-pane -P "bg=#000000"'
        set-hook -g pane-focus-out 'select-pane -P "bg=#2a2a2a"'
        
        # Initialize all panes with inactive style
        set-hook -g after-new-window 'select-pane -P "bg=#2a2a2a"'
        set-hook -g after-split-window 'select-pane -P "bg=#2a2a2a"'
      '';
    };
  };
}
