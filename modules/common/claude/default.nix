{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Bubblewrap-sandboxed Claude Code with restricted filesystem access
  claude-code-sandboxed = pkgs.buildFHSEnvBubblewrap {
    name = "claude";
    runScript = "${pkgs.unstable.claude-code}/bin/claude";
    targetPkgs = pkgs: [ pkgs.unstable.claude-code ];

    unshareUser = false;
    unshareIpc = true;
    unsharePid = true;
    unshareUts = true;
    privateTmp = true;

    extraBwrapArgs = [
      "--hostname"
      "claude-sandbox"
      "--size"
      "67108864"
      "--tmpfs"
      "/home"
      "--dir"
      "/home/jack"

      # Read-only mounts
      "--ro-bind-try"
      "\${HOME}/.gitconfig"
      "\${HOME}/.gitconfig"
      "--ro-bind-try"
      "\${HOME}/.ssh"
      "\${HOME}/.ssh"
      "--ro-bind-try"
      "\${HOME}/.gnupg"
      "\${HOME}/.gnupg"
      "--ro-bind-try"
      "\${HOME}/.tmux"
      "\${HOME}/.tmux"
      "--ro-bind-try"
      "\${HOME}/.config"
      "\${HOME}/.config"
      "--ro-bind-try"
      "\${HOME}/.themes"
      "\${HOME}/.themes"
      "--ro-bind-try"
      "\${HOME}/.bashrc"
      "\${HOME}/.bashrc"
      "--ro-bind-try"
      "\${HOME}/.bash_profile"
      "\${HOME}/.bash_profile"
      "--ro-bind-try"
      "\${HOME}/.profile"
      "\${HOME}/.profile"
      "--ro-bind-try"
      "\${HOME}/.zshrc"
      "\${HOME}/.zshrc"
      "--ro-bind-try"
      "\${HOME}/.zshenv"
      "\${HOME}/.zshenv"

      # Read-write mounts
      "--bind-try"
      "\${HOME}/repos"
      "\${HOME}/repos"
      "--bind-try"
      "\${HOME}/.cache"
      "\${HOME}/.cache"
      "--bind-try"
      "\${HOME}/.npm"
      "\${HOME}/.npm"
      "--bind-try"
      "\${HOME}/.cargo"
      "\${HOME}/.cargo"
      "--bind-try"
      "\${HOME}/.local"
      "\${HOME}/.local"
      "--bind-try"
      "\${HOME}/.claude"
      "\${HOME}/.claude"
      "--bind-try"
      "\${HOME}/.claude.json"
      "\${HOME}/.claude.json"
      "--bind-try"
      "\${HOME}/.claude.json.backup"
      "\${HOME}/.claude.json.backup"
      "--bind-try"
      "\${HOME}/.aws"
      "\${HOME}/.aws"
      "--bind-try"
      "\${HOME}/.kube"
      "\${HOME}/.kube"
    ];
  };

  # Build the notification hook script as a derivation
  claudeNotifyHook = pkgs.stdenv.mkDerivation {
    pname = "claude-notify-hook";
    version = "1.0.0";

    src = ./scripts;

    buildInputs = [
      pkgs.bash
      pkgs.jq
    ];

    installPhase = ''
      mkdir -p $out/bin

      # Substitute placeholders with actual paths in notify-hook script
      substitute $src/notify-hook.sh $out/bin/claude-notify-hook \
        --replace "@notify-send@" "${pkgs.libnotify}/bin/notify-send" \
        --replace "@jq@" "${pkgs.jq}/bin/jq" \
        --replace "@claude@" "${pkgs.unstable.claude-code}/bin/claude"

      # Copy and prepare the extract-conversation script
      substitute $src/extract-conversation.sh $out/bin/extract-conversation \
        --replace "jq" "${pkgs.jq}/bin/jq" \
        --replace "grep" "${pkgs.gnugrep}/bin/grep"

      # Update notify-hook to use the installed extract-conversation script
      substituteInPlace $out/bin/claude-notify-hook \
        --replace '"$script_dir/extract-conversation.sh"' '"${placeholder "out"}/bin/extract-conversation"'

      chmod +x $out/bin/claude-notify-hook
      chmod +x $out/bin/extract-conversation
    '';
  };

  # Path to the built notification hook
  notifyHook = "${claudeNotifyHook}/bin/claude-notify-hook";
in
{
  # Claude Code configuration and hooks
  home-manager.users.${config.username} = {
    # Zsh alias for claude with dangerously-skip-permissions
    programs.zsh.shellAliases = {
      cc = "claude --dangerously-skip-permissions";
    };

    # Claude Code settings with notification hooks
    home.file.".claude/settings.json".text = builtins.toJSON {
      attribution = {
        commit = "";
        pr = "";
      };
      env = {
        DISABLE_AUTOUPDATER = "1";
        DISABLE_TELEMETRY = "1";
        CLAUDE_CODE_HIDE_ACCOUNT_INFO = "1";
        CLAUDE_CODE_IDE_SKIP_AUTO_INSTALL = "1";
        CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
        DISABLE_NON_ESSENTIAL_MODEL_CALLS = "1";
        DISABLE_ERROR_REPORTING = "1";
      };
      hooks = {
        # Notification hook - triggers when Claude needs permission or is waiting
        Notification = [
          {
            matcher = "permission_prompt|elicitation_dialog";
            hooks = [
              {
                type = "command";
                command = "workmux set-window-status waiting";
              }
            ];
          }
        ];

        # When main agent stops and might be waiting for input
        Stop = [
          {
            matcher = ".*";
            hooks = [
              {
                type = "command";
                command = "workmux set-window-status done";
              }
            ];
          }
        ];

        # When user submits a prompt - used to mark the Sway container
        UserPromptSubmit = [
          {
            matcher = ".*";
            hooks = [
              {
                type = "command";
                command = "workmux set-window-status working";
              }
            ];
          }
        ];
      };
    };
  };

  # Also make the script available in system packages for testing
  environment.systemPackages = [
    claudeNotifyHook
    claude-code-sandboxed
  ];
}
