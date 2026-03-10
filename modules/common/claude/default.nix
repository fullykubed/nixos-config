{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
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
        runScript = "${nixpkgs-unstable.claude-code}/bin/claude";
        targetPkgs = _pkgs: [ nixpkgs-unstable.claude-code ];

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

          # Environment variables (set at bwrap level so all child processes inherit)
          "--setenv"
          "HTTP_PROXY"
          "http://127.0.0.1:8080"
          "--setenv"
          "HTTPS_PROXY"
          "http://127.0.0.1:8080"
          "--setenv"
          "http_proxy"
          "http://127.0.0.1:8080"
          "--setenv"
          "https_proxy"
          "http://127.0.0.1:8080"
          "--setenv"
          "GH_TOKEN"
          "proxy-injected"
          "--setenv"
          "SHELL"
          "${pkgs.bashInteractive}/bin/bash"

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

          "--ro-bind-try"
          "/var/lib/mitmproxy-credential-proxy/mitmproxy-ca-cert.pem"
          "/var/lib/mitmproxy-credential-proxy/mitmproxy-ca-cert.pem"
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
            --replace "@claude@" "${claude-code-sandboxed}/bin/claude"

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

      aiCommitMsg = pkgs.writeShellScriptBin "ai-commit-msg" (builtins.readFile ./scripts/ai-commit-msg);

      aiCommit = pkgs.writeShellScriptBin "ai-commit" (builtins.readFile ./scripts/ai-commit);

      aiReword = pkgs.writeShellScriptBin "ai-reword" (builtins.readFile ./scripts/ai-reword);

      aiAmend = pkgs.writeShellScriptBin "ai-amend" (builtins.readFile ./scripts/ai-amend);

      aiRebase = pkgs.writeShellScriptBin "ai-rebase" (builtins.readFile ./scripts/ai-rebase);

      aiSquashCommits = pkgs.writeShellScriptBin "ai-squash-commits" (
        builtins.readFile ./scripts/ai-squash-commits
      );

      claudeShellScripts = pkgs.stdenv.mkDerivation {
        pname = "claude-shell-scripts";
        version = "1.0.0";

        src = ./scripts;

        buildInputs = [ pkgs.bash ];

        installPhase = ''
          mkdir -p $out/bin

          substitute $src/una.sh $out/bin/claude-una \
            --replace "@hostname@" "${pkgs.hostname}/bin/hostname" \
            --replace "@home@" "/home/${config.username}"
          chmod +x $out/bin/claude-una

          cp $src/q.sh $out/bin/claude-q
          chmod +x $out/bin/claude-q

          cp $src/qq.sh $out/bin/claude-qq
          chmod +x $out/bin/claude-qq

          cp $src/qqq.sh $out/bin/claude-qqq
          chmod +x $out/bin/claude-qqq
        '';
      };

      claude-wrapper = pkgs.writeShellScriptBin "claude-wrapper" ''
        exec ${claude-code-sandboxed}/bin/claude --dangerously-skip-permissions "$@"
      '';

      claudeSkill = pkgs.callPackage ./skills/Skill { };

      claudePRD = pkgs.callPackage ./skills/PRD { };

      claudeDevBrowser = pkgs.callPackage ./skills/DevBrowser { };

      claudeNixOSBuild = pkgs.callPackage ./skills/NixOSBuild { homeDir = "/home/${config.username}"; };

      claudeSurprises = pkgs.callPackage ./skills/Surprises { inherit nixpkgs-unstable; };

      claudeKeePassXC = pkgs.callPackage ./skills/KeePassXC { };
      claudeGitHub = pkgs.callPackage ./skills/GitHub { };
      claudeGit = pkgs.callPackage ./skills/Git { };
    in
    {
      home-manager.users.${config.username} = {
        programs.zsh = {
          shellAliases = {
            cc = "claude-wrapper";
            una = "claude-una";
            q = "noglob claude-q";
            qq = "noglob claude-qq";
            qqq = "noglob claude-qqq";
          };
        };

        home.file = {
          ".claude/CLAUDE.md" = {
            source = ./CLAUDE.md;
          };

          ".claude/commands" = {
            source = ./commands;
            recursive = true;
          };

          ".claude/specs" = {
            source = ./specs;
            recursive = true;
          };

          ".claude/settings.json" = {
            force = true;
            text = builtins.toJSON {
              skipDangerousModePermissionPrompt = true;
              sandbox = {
                enabled = false; # We provide our own bwrap sandbox via claude-code-sandboxed
              };
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
                      {
                        type = "command";
                        command = "${claudeSurprises.hookPackage}/bin/claude-surprise-hook";
                        async = true;
                        timeout = 900;
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

                PostToolUse = claudePRD.hooks.PostToolUse ++ claudeSkill.hooks.PostToolUse;
              };
            };
          };
        }
        // claudeSkill.homeFiles
        // claudePRD.homeFiles
        // claudeDevBrowser.homeFiles
        // claudeNixOSBuild.homeFiles
        // claudeSurprises.homeFiles
        // claudeKeePassXC.homeFiles
        // claudeGitHub.homeFiles
        // claudeGit.homeFiles;

        home.activation.injectExaMcpKey = {
          after = [ "writeBoundary" ];
          before = [ ];
          data = ''
            CLAUDE_JSON="$HOME/.claude.json"
            EXA_TOKEN_PATH="${config.age.secrets.exa-token.path}"
            EXA_TOOLS="web_search_exa,get_code_context_exa,deep_researcher_start,deep_researcher_check"

            if [[ ! -f "$CLAUDE_JSON" ]]; then
              echo '{}' > "$CLAUDE_JSON"
            fi

            # Set dark mode, auto-trust home directory, and runtime preferences
            ${pkgs.jq}/bin/jq '
              .theme = "dark" |
              .projects["/home/${config.username}"].hasTrustDialogAccepted = true |
              .autoCompactEnabled = true |
              .fileCheckpointingEnabled = true |
              .respectGitignore = true |
              .preferTmuxOverIterm2 = true |
              .autoConnectIde = false |
              .autoInstallIdeExtension = false
            ' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp"
            mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"

            if [[ -f "$EXA_TOKEN_PATH" ]]; then
              EXA_API_KEY="$(cat "$EXA_TOKEN_PATH")"
              ${pkgs.jq}/bin/jq --arg key "$EXA_API_KEY" --arg tools "$EXA_TOOLS" '.mcpServers.exa = {type: "http", url: "https://mcp.exa.ai/mcp?exaApiKey=\($key)&tools=\($tools)"}' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp"
              mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
            fi
          '';
        };
      };

      environment.systemPackages = [
        claudeNotifyHook
        claudeSurprises.hookPackage
        claudeShellScripts
        claudePRD.package
        claudeSkill.package
        claudeDevBrowser.package
        claudeNixOSBuild.package
        claudeSurprises.package
        claudeKeePassXC.package
        claudeGitHub.package
        aiCommitMsg
        aiCommit
        aiReword
        aiAmend
        aiRebase
        aiSquashCommits
        claude-code-sandboxed
        claude-wrapper
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
