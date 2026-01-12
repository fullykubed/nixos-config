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

  # ccusage - Claude Code usage tracking
  ccusageVersion = "16.2.5";
  ccusage = pkgs.stdenv.mkDerivation rec {
    pname = "ccusage";
    version = ccusageVersion;

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/ccusage/-/ccusage-${version}.tgz";
      hash = "sha256-GXleBpZ3XF4DWrXG31Kh15SoOLRm6kXuuvIEEEmQ8eA=";
    };

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/node_modules/ccusage
      cp -r ./* $out/lib/node_modules/ccusage/

      mkdir -p $out/bin
      makeWrapper ${pkgs.nodejs_20}/bin/node $out/bin/ccusage \
        --add-flags "$out/lib/node_modules/ccusage/dist/index.js"

      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Claude Code usage tracking and cost analysis";
      homepage = "https://github.com/ryoppippi/ccusage";
      license = licenses.mit;
      mainProgram = "ccusage";
    };
  };

  # Build the PRD task management scripts
  claudeTaskScripts = pkgs.stdenv.mkDerivation {
    pname = "claude-task-scripts";
    version = "1.0.0";

    src = ./scripts;

    buildInputs = [
      pkgs.bash
      pkgs.yq-go
      pkgs.jq
      pkgs.check-jsonschema
    ];

    installPhase = ''
      mkdir -p $out/bin $out/share/claude

      # Copy schema files
      cp ${./specs/tasks.schema.json} $out/share/claude/tasks.schema.json
      cp ${./specs/research.schema.json} $out/share/claude/research.schema.json

      # claude-task-status script
      substitute $src/task-status.sh $out/bin/claude-task-status \
        --replace "@yq@" "${pkgs.yq-go}/bin/yq"
      chmod +x $out/bin/claude-task-status

      # claude-update-task-status script
      substitute $src/update-task-status.sh $out/bin/claude-update-task-status \
        --replace "@yq@" "${pkgs.yq-go}/bin/yq"
      chmod +x $out/bin/claude-update-task-status

      # claude-validate-tasks script
      substitute $src/validate-tasks.sh $out/bin/claude-validate-tasks \
        --replace "@yq@" "${pkgs.yq-go}/bin/yq" \
        --replace "@check-jsonschema@" "${pkgs.check-jsonschema}/bin/check-jsonschema" \
        --replace "@schema-path@" "$out/share/claude/tasks.schema.json"
      chmod +x $out/bin/claude-validate-tasks

      # claude-list-prds script
      substitute $src/list-prds.sh $out/bin/claude-list-prds \
        --replace "@yq@" "${pkgs.yq-go}/bin/yq" \
        --replace "@jq@" "${pkgs.jq}/bin/jq"
      chmod +x $out/bin/claude-list-prds

      # claude-research-status script
      substitute $src/research-status.sh $out/bin/claude-research-status \
        --replace "@yq@" "${pkgs.yq-go}/bin/yq"
      chmod +x $out/bin/claude-research-status

      # claude-validate-research script
      substitute $src/validate-research.sh $out/bin/claude-validate-research \
        --replace "@check-jsonschema@" "${pkgs.check-jsonschema}/bin/check-jsonschema" \
        --replace "@schema-path@" "$out/share/claude/research.schema.json"
      chmod +x $out/bin/claude-validate-research

      # claude-list-draft-tasks script
      substitute $src/list-prd-draft-tasks.sh $out/bin/claude-list-draft-tasks \
        --replace "@yq@" "${pkgs.yq-go}/bin/yq" \
        --replace "@jq@" "${pkgs.jq}/bin/jq"
      chmod +x $out/bin/claude-list-draft-tasks

      # claude-list-defined-tasks script
      substitute $src/list-defined-tasks.sh $out/bin/claude-list-defined-tasks \
        --replace "@yq@" "${pkgs.yq-go}/bin/yq" \
        --replace "@jq@" "${pkgs.jq}/bin/jq"
      chmod +x $out/bin/claude-list-defined-tasks

      # claude-get-task script
      substitute $src/get-task.sh $out/bin/claude-get-task \
        --replace "@yq@" "${pkgs.yq-go}/bin/yq" \
        --replace "@jq@" "${pkgs.jq}/bin/jq"
      chmod +x $out/bin/claude-get-task
    '';
  };
in
{
  # Claude Code configuration and hooks
  home-manager.users.${config.username} = {
    # Zsh alias for claude with dangerously-skip-permissions
    programs.zsh.shellAliases = {
      cc = "claude --dangerously-skip-permissions";
    };

    # Deploy skill configurations
    home.file.".claude/skills" = {
      source = ./skills;
      recursive = true;
    };

    # Deploy PRD and task specifications (referenced by skills via @)
    home.file.".claude/specs" = {
      source = ./specs;
      recursive = true;
    };

    # Claude Code settings with notification hooks
    home.file.".claude/settings.json" = {
      force = true;
      text = builtins.toJSON {
      statusLine = {
        type = "command";
        command = "${ccusage}/bin/ccusage statusline --visual-burn-rate emoji";
        padding = 0;
      };
      spinnerTipsEnabled = false;
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

    # Activation script to inject exa MCP server into ~/.claude.json (user scope)
    home.activation.injectExaMcpKey = {
      after = [ "writeBoundary" ];
      before = [ ];
      data = ''
        CLAUDE_JSON="$HOME/.claude.json"
        EXA_TOKEN_PATH="${config.age.secrets.exa-token.path}"
        EXA_TOOLS="web_search_exa,get_code_context_exa,deep_researcher_start,deep_researcher_check"

        if [[ -f "$EXA_TOKEN_PATH" ]]; then
          EXA_API_KEY="$(cat "$EXA_TOKEN_PATH")"
          # Create file with empty object if it doesn't exist
          if [[ ! -f "$CLAUDE_JSON" ]]; then
            echo '{}' > "$CLAUDE_JSON"
          fi
          ${pkgs.jq}/bin/jq --arg key "$EXA_API_KEY" --arg tools "$EXA_TOOLS" '.mcpServers.exa = {type: "http", url: "https://mcp.exa.ai/mcp?exaApiKey=\($key)&tools=\($tools)"}' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp"
          mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
        fi
      '';
    };
  };

  # Also make the script available in system packages for testing
  environment.systemPackages = [
    claudeNotifyHook
    claudeTaskScripts
    claude-code-sandboxed
    ccusage
  ];

  # Exa API token for MCP server
  age.secrets = {
    exa-token = {
      rekeyFile = ../../../secrets/exa-token.age;
      owner = config.username;
      group = "users";
      mode = "0400";
    };
  };
}
