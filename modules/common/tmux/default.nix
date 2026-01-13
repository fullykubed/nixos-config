{
  config,
  pkgs,
  lib,
  ...
}:
{
  # ===========================================================================
  # Version Options
  # ===========================================================================
  options.versions = {
    workmux = lib.mkOption {
      type = lib.types.str;
      description = "Version of workmux CLI tool";
    };
    workmuxRev = lib.mkOption {
      type = lib.types.str;
      description = "Git revision for workmux source";
    };
    workmuxSrcHash = lib.mkOption {
      type = lib.types.str;
      description = "Source hash for workmux";
    };
    workmuxCargoHash = lib.mkOption {
      type = lib.types.str;
      description = "Cargo hash for workmux";
    };

    tmuxAutoreload = lib.mkOption {
      type = lib.types.str;
      description = "Version of tmux-autoreload plugin";
    };
    tmuxAutoreloadRev = lib.mkOption {
      type = lib.types.str;
      description = "Git revision for tmux-autoreload";
    };
    tmuxAutoreloadHash = lib.mkOption {
      type = lib.types.str;
      description = "Source hash for tmux-autoreload";
    };

    tmuxNotify = lib.mkOption {
      type = lib.types.str;
      description = "Version of tmux-notify plugin";
    };
    tmuxNotifyRev = lib.mkOption {
      type = lib.types.str;
      description = "Git revision for tmux-notify";
    };
    tmuxNotifyHash = lib.mkOption {
      type = lib.types.str;
      description = "Source hash for tmux-notify";
    };
  };

  # ===========================================================================
  # Configuration
  # ===========================================================================
  config =
    let
      inherit (config) versions;

      workmux = pkgs.rustPlatform.buildRustPackage {
        pname = "workmux";
        version = versions.workmux;

        src = pkgs.fetchFromGitHub {
          owner = "raine";
          repo = "workmux";
          rev = versions.workmuxRev;
          hash = versions.workmuxSrcHash;
        };

        cargoHash = versions.workmuxCargoHash;

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
          libnotify
          sesh
          workmux
        ];

        xdg.configFile."workmux/config.yaml".text = ''
          merge_strategy: rebase
          agent: cc
          worktree_naming: full
          worktree_dir: ../
          window_prefix: "\uf418 "

          panes:
            - command: nvim .
            - command: <agent>
              split: vertical
              percentage: 33
              focus: true
            - split: horizontal

          post_create:
            - direnv allow

          files:
            copy:
              - .env
        '';

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

        programs = {
          zsh = {
            initContent = ''
              eval "$(workmux completions zsh)"

              _wmab() {
                local prompt="$*"
                local repo_branches
                repo_branches=$(git branch -a --sort=-committerdate 2>/dev/null | head -10 | sed 's/^[* ]*//' | sed 's|remotes/origin/||' | grep -v '^HEAD' | tr '\n' ', ' | sed 's/, $//')
                local branch_name
                branch_name=$(claude -p \
                  --model haiku \
                  --tools "" \
                  --no-session-persistence \
                  --output-format json \
                  --json-schema '{"type":"object","properties":{"branch":{"type":"string","pattern":"^[a-z0-9][a-z0-9/-]*[a-z0-9]$"}},"required":["branch"],"additionalProperties":false}' \
                  --system-prompt "Generate a concise git branch name. Rules: kebab-case (lowercase with hyphens), 2-4 words max, focus on core task or feature not implementation details. By default avoid prefixes like feat/ or fix/, but if the repository examples use that pattern, follow it. Repository branch examples: $repo_branches" \
                  "$prompt" | jq -r '.structured_output.branch')
                workmux add -b -p "$prompt" "$branch_name"
              }
            '';

            shellAliases = {
              wm = "workmux";
              wmm = "workmux merge";
              wmab = "noglob _wmab";
            };
          };

          tmux = {
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
                extraConfig = "set -g @resurrect-capture-pane-contents 'on'";
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
                  version = versions.tmuxAutoreload;
                  rtpFilePath = "tmux-autoreload.tmux";
                  src = pkgs.fetchFromGitHub {
                    owner = "b0o";
                    repo = "tmux-autoreload";
                    rev = versions.tmuxAutoreloadRev;
                    sha256 = versions.tmuxAutoreloadHash;
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
                  version = versions.tmuxNotify;
                  rtpFilePath = "tnotify.tmux";
                  src = pkgs.fetchFromGitHub {
                    owner = "rickstaa";
                    repo = "tmux-notify";
                    rev = versions.tmuxNotifyRev;
                    sha256 = versions.tmuxNotifyHash;
                  };
                };
                extraConfig = ''
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
                set -g window-style 'bg=${config.lib.stylix.colors.withHashtag.base00}'
                set -g window-active-style 'bg=${config.lib.stylix.colors.withHashtag.base01}'

                unbind C-b
                set -g prefix C-a
                bind C-a send-prefix

                bind | split-window -h -c "#{pane_current_path}"
                bind - split-window -v -c "#{pane_current_path}"
                unbind '"'
                unbind %

                bind r command-prompt -I "#W" "rename-window '%%'"
                bind R command-prompt -I "#S" "rename-session '%%'"

                bind -n M-R source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"

                bind -r h resize-pane -L 5
                bind -r j resize-pane -D 5
                bind -r k resize-pane -U 5
                bind -r l resize-pane -R 5

                bind -n M-h swap-pane -d -t '{left-of}'
                bind -n M-j swap-pane -d -t '{down-of}'
                bind -n M-k swap-pane -d -t '{up-of}'
                bind -n M-l swap-pane -d -t '{right-of}'

                bind -n M-r rotate-window
                bind -n M-e rotate-window -D

                bind m resize-pane -Z

                bind -n M-m select-layout main-horizontal \; run-shell "tmux resize-pane -t 0 -y \$((\$(tmux display -p '#{window_height}') * 70 / 100))"

                bind -n M-n next-window
                bind -n M-p previous-window

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

                bind c new-window -c "#{pane_current_path}"

                bind -n M-x kill-pane
                bind -n M-X kill-window

                bind Enter copy-mode
                bind -T copy-mode-vi v send-keys -X begin-selection
                bind -T copy-mode-vi C-v send-keys -X rectangle-toggle
                bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel
                bind -T copy-mode-vi Escape send-keys -X cancel

                bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'wl-copy'
                bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel 'wl-copy'

                set -g status-position top
                set -g status-interval 5
                set -g status-justify left

                set -g default-terminal "tmux-256color"
                set-option -sa terminal-features ''',wezterm:RGB'''
                set-option -ga terminal-features ",wezterm:usstyle"
                set-option -ga terminal-overrides ",*:Tc"

                set -g focus-events on

                setw -g monitor-activity on
                set -g visual-activity off

                set -g renumber-windows on

                set -g set-titles on
                set -g set-titles-string "#S / #W"

                set -g message-style fg=${config.lib.stylix.colors.withHashtag.base00},bg=${config.lib.stylix.colors.withHashtag.base0D},bold

                set -g mode-style fg=${config.lib.stylix.colors.withHashtag.base05},bg=${config.lib.stylix.colors.withHashtag.base03}

                set -g pane-border-lines single
                set -g popup-border-lines rounded
                set -g pane-border-status off
                set -g pane-border-indicators off
                set -g pane-border-style fg=default,bg=default
                set -g pane-active-border-style fg=default,bg=default
                set -g popup-border-style fg=${config.lib.stylix.colors.withHashtag.base0D},bg=default

                bind -n M-c new-window -c "#{pane_current_path}"

                bind -n M-C attach-session -c "#{pane_current_path}"

                bind -n M-Enter display-popup -d "#{pane_current_path}" -h 80% -w 80% -E

                set -g mouse on
                bind -n WheelUpPane if -F '#{alternate_on}' 'send-keys Up' 'if -F "#{mouse_any_flag}" "send -M" "copy-mode -e; send-keys -M"'
                bind -n WheelDownPane if -F '#{alternate_on}' 'send-keys Down' 'send-keys -M'

              	bind-key x kill-pane
              	set -g detach-on-destroy off
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

                bind -n M-a display-popup -h 90% -w 90% -E "workmux dashboard"

                bind -n M-g display-popup -d "#{pane_current_path}" -h 90% -w 90% -E "lazygit"

                bind -n M-w display-popup -d "#{pane_current_path}" -h 90% -w 90% -E "lazyworktree"

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
      };
    };
}
