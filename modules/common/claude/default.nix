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
    ccusage = lib.mkOption {
      type = lib.types.str;
      description = "Version of ccusage Claude Code usage tracker";
    };
    ccusageSrcHash = lib.mkOption {
      type = lib.types.str;
      description = "Source hash for ccusage NPM package";
    };
  };

  # ===========================================================================
  # Configuration
  # ===========================================================================
  config =
    let
      inherit (config) versions;

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

          substitute $src/notify-hook.sh $out/bin/claude-notify-hook \
            --replace "@notify-send@" "${pkgs.libnotify}/bin/notify-send" \
            --replace "@jq@" "${pkgs.jq}/bin/jq" \
            --replace "@claude@" "${pkgs.unstable.claude-code}/bin/claude"

          substitute $src/extract-conversation.sh $out/bin/extract-conversation \
            --replace "jq" "${pkgs.jq}/bin/jq" \
            --replace "grep" "${pkgs.gnugrep}/bin/grep"

          substituteInPlace $out/bin/claude-notify-hook \
            --replace '"$script_dir/extract-conversation.sh"' '"${placeholder "out"}/bin/extract-conversation"'

          chmod +x $out/bin/claude-notify-hook
          chmod +x $out/bin/extract-conversation
        '';
      };

      ccusage = pkgs.stdenv.mkDerivation {
        pname = "ccusage";
        version = versions.ccusage;

        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/ccusage/-/ccusage-${versions.ccusage}.tgz";
          hash = versions.ccusageSrcHash;
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

      claudeTaskScripts = pkgs.stdenv.mkDerivation {
        pname = "claude-task-scripts";
        version = "1.0.0";

        src = ./skills/PRD/scripts;

        buildInputs = [
          pkgs.bash
          pkgs.yq-go
          pkgs.jq
          pkgs.check-jsonschema
        ];

        installPhase = ''
          mkdir -p $out/bin $out/share/claude

          cp ${./skills/PRD/schemas/tasks.schema.json} $out/share/claude/tasks.schema.json
          cp ${./skills/PRD/schemas/research.schema.json} $out/share/claude/research.schema.json

          substitute $src/task-status.sh "$out/bin/claude-PRD-task-status" \
            --replace "@yq@" "${pkgs.yq-go}/bin/yq"
          chmod +x "$out/bin/claude-PRD-task-status"

          substitute $src/update-task-status.sh "$out/bin/claude-PRD-update-task-status" \
            --replace "@yq@" "${pkgs.yq-go}/bin/yq"
          chmod +x "$out/bin/claude-PRD-update-task-status"

          substitute ${./hooks/validate-tasks.sh} "$out/bin/claude-PRD-validate-tasks" \
            --replace "@yq@" "${pkgs.yq-go}/bin/yq" \
            --replace "@check-jsonschema@" "${pkgs.check-jsonschema}/bin/check-jsonschema" \
            --replace "@schema-path@" "$out/share/claude/tasks.schema.json" \
            --replace "@jq@" "${pkgs.jq}/bin/jq"
          chmod +x "$out/bin/claude-PRD-validate-tasks"

          substitute $src/list-prds.sh "$out/bin/claude-PRD-list-prds" \
            --replace "@yq@" "${pkgs.yq-go}/bin/yq" \
            --replace "@jq@" "${pkgs.jq}/bin/jq"
          chmod +x "$out/bin/claude-PRD-list-prds"

          substitute $src/research-status.sh "$out/bin/claude-PRD-research-status" \
            --replace "@yq@" "${pkgs.yq-go}/bin/yq"
          chmod +x "$out/bin/claude-PRD-research-status"

          substitute ${./hooks/validate-research.sh} "$out/bin/claude-PRD-validate-research" \
            --replace "@check-jsonschema@" "${pkgs.check-jsonschema}/bin/check-jsonschema" \
            --replace "@schema-path@" "$out/share/claude/research.schema.json" \
            --replace "@jq@" "${pkgs.jq}/bin/jq"
          chmod +x "$out/bin/claude-PRD-validate-research"

          substitute $src/list-prd-draft-tasks.sh "$out/bin/claude-PRD-list-draft-tasks" \
            --replace "@yq@" "${pkgs.yq-go}/bin/yq" \
            --replace "@jq@" "${pkgs.jq}/bin/jq"
          chmod +x "$out/bin/claude-PRD-list-draft-tasks"

          substitute $src/list-defined-tasks.sh "$out/bin/claude-PRD-list-defined-tasks" \
            --replace "@yq@" "${pkgs.yq-go}/bin/yq" \
            --replace "@jq@" "${pkgs.jq}/bin/jq"
          chmod +x "$out/bin/claude-PRD-list-defined-tasks"

          substitute $src/get-task.sh "$out/bin/claude-PRD-get-task" \
            --replace "@yq@" "${pkgs.yq-go}/bin/yq" \
            --replace "@jq@" "${pkgs.jq}/bin/jq"
          chmod +x "$out/bin/claude-PRD-get-task"

          substitute $src/get-unanswered-research.sh "$out/bin/claude-PRD-get-unanswered-research" \
            --replace "@yq@" "${pkgs.yq-go}/bin/yq"
          chmod +x "$out/bin/claude-PRD-get-unanswered-research"
        '';
      };
    in
    {
      home-manager.users.${config.username} = {
        programs.zsh = {
          shellAliases = {
            cc = "claude --dangerously-skip-permissions";
            q = "noglob _q";
            qq = "noglob _qq";
            qqq = "noglob _qqq";
          };

          initContent = ''
            _q() {
              claude -p --dangerously-skip-permissions --model opus --tools "" --allowedTools "WebSearch" --system-prompt "You answer questions concisely for terminal output. Use WebSearch to find current information when needed. Format responses in markdown, keeping them under 50 lines. Be direct and factual. Include sources when citing specific facts." "$*" | glow
            }

            _qq() {
              claude -p --dangerously-skip-permissions --model sonnet --tools "" --allowedTools "mcp__exa__get_code_context_exa" --system-prompt "You are a code assistant. Use the mcp__exa__get_code_context_exa tool to find relevant code examples, API documentation, and library usage patterns. Return concise, practical answers under 50 lines. Focus on working code examples. Format with markdown code blocks." "$*" | glow
            }

            _qqq() {
              claude -p --dangerously-skip-permissions --model sonnet --tools "" --allowedTools "mcp__exa__deep_researcher_start,mcp__exa__deep_researcher_check" --system-prompt "You are a research assistant. Use mcp__exa__deep_researcher_start to begin research, then poll with mcp__exa__deep_researcher_check until complete. Synthesize findings into a concise summary under 80 lines. Include key citations. Format with markdown." "$*" | glow
            }
          '';
        };

        home.file = {
          ".claude/skills" = {
            source = ./skills;
            recursive = true;
          };

          ".claude/commands" = {
            source = ./commands;
            recursive = true;
          };

          ".claude/specs" = {
            source = ./specs;
            recursive = true;
          };

          ".claude/agents" = {
            source = ./agents;
            recursive = true;
          };

          ".claude/settings.json" = {
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

                PostToolUse = [
                  {
                    matcher = "Edit|Write";
                    hooks = [
                      {
                        type = "command";
                        command = "${claudeTaskScripts}/bin/claude-PRD-validate-research";
                      }
                      {
                        type = "command";
                        command = "${claudeTaskScripts}/bin/claude-PRD-validate-tasks";
                      }
                    ];
                  }
                ];
              };
            };
          };
        };

        home.activation.injectExaMcpKey = {
          after = [ "writeBoundary" ];
          before = [ ];
          data = ''
            CLAUDE_JSON="$HOME/.claude.json"
            EXA_TOKEN_PATH="${config.age.secrets.exa-token.path}"
            EXA_TOOLS="web_search_exa,get_code_context_exa,deep_researcher_start,deep_researcher_check"

            if [[ -f "$EXA_TOKEN_PATH" ]]; then
              EXA_API_KEY="$(cat "$EXA_TOKEN_PATH")"
              if [[ ! -f "$CLAUDE_JSON" ]]; then
                echo '{}' > "$CLAUDE_JSON"
              fi
              ${pkgs.jq}/bin/jq --arg key "$EXA_API_KEY" --arg tools "$EXA_TOOLS" '.mcpServers.exa = {type: "http", url: "https://mcp.exa.ai/mcp?exaApiKey=\($key)&tools=\($tools)"}' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp"
              mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
            fi
          '';
        };
      };

      environment.systemPackages = [
        claudeNotifyHook
        claudeTaskScripts
        claude-code-sandboxed
        ccusage
      ];

      age.secrets = {
        exa-token = {
          rekeyFile = ../../../secrets/exa-token.age;
          owner = config.username;
          group = "users";
          mode = "0400";
        };
      };
    };
}
