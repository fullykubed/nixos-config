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
    betterCcflare = lib.mkOption {
      type = lib.types.str;
      description = "Version of better-ccflare Claude API load balancer";
    };
    betterCcflareSrcHash = lib.mkOption {
      type = lib.types.str;
      description = "Source hash for better-ccflare GitHub source";
    };
    headroom = lib.mkOption {
      type = lib.types.str;
      description = "Version of headroom context compression proxy";
    };
    headroomSrcHash = lib.mkOption {
      type = lib.types.str;
      description = "Source hash for headroom PyPI package";
    };
    agentBrowser = lib.mkOption {
      type = lib.types.str;
      description = "Version of agent-browser browser automation CLI";
    };
    agentBrowserSrcHash = lib.mkOption {
      type = lib.types.str;
      description = "Source hash for agent-browser GitHub source";
    };
    agentBrowserPnpmDepsHash = lib.mkOption {
      type = lib.types.str;
      description = "Hash for agent-browser pnpm dependency store (pnpm_9.fetchDeps)";
    };
    agentBrowserCargoHash = lib.mkOption {
      type = lib.types.str;
      description = "Cargo vendor hash for agent-browser Rust CLI";
    };
  };

  # ===========================================================================
  # Configuration
  # ===========================================================================
  config =
    let
      inherit (config) versions;

      extractFrontmatter = pkgs.callPackage ./lib/extract-frontmatter.nix { };

      # Helper: expand a list of paths into --ro-bind-try or --bind-try triples.
      roBind =
        paths:
        lib.concatMap (p: [
          "--ro-bind-try"
          p
          p
        ]) paths;
      rwBind =
        paths:
        lib.concatMap (p: [
          "--bind-try"
          p
          p
        ]) paths;

      claude-code-sandboxed = pkgs.buildFHSEnvBubblewrap {
        name = "claude";
        runScript = pkgs.writeShellScript "claude-sandboxed-run" ''
          exec ${nixpkgs-unstable.claude-code}/bin/claude "$@"
        '';
        targetPkgs = _pkgs: [ nixpkgs-unstable.claude-code ];

        unshareUser = false;
        unshareIpc = true;
        unsharePid = true;
        unshareUts = true;
        privateTmp = true;

        # Exclude /run from auto-mounts so agenix secrets aren't exposed.
        # We mount a clean tmpfs and selectively bind only what's needed.
        profile = ''
          export PATH="/opt/find-grep/bin:$PATH"
        '';

        extraPreBwrapCmds = ''
          ignored+=(/run)
          _run_uid=$(id -u)
        '';

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
          # TEMP DISABLED: MITM proxy
          # "--setenv"
          # "HTTP_PROXY"
          # "http://127.0.0.1:8080"
          # "--setenv"
          # "HTTPS_PROXY"
          # "http://127.0.0.1:8080"
          # "--setenv"
          # "http_proxy"
          # "http://127.0.0.1:8080"
          # "--setenv"
          # "https_proxy"
          # "http://127.0.0.1:8080"
          # "--setenv"
          # "GH_TOKEN"
          # "proxy-injected"
          "--setenv"
          "SHELL"
          "${pkgs.bashInteractive}/bin/bash"
          # Force xdg-open to use the XDG Desktop Portal (NixOS patch).
          # Without this, xdg-open launches Firefox directly inside the
          # sandbox where privateTmp isolates /tmp, preventing Firefox from
          # finding the host instance's IPC socket — so it starts a new
          # blocking GUI process instead of opening a tab. With this set,
          # xdg-open calls org.freedesktop.portal.OpenURI via D-Bus, which
          # xdg-desktop-portal handles internally (v1.18+), resolving the
          # default handler and calling org.mozilla.firefox.OpenURL on the
          # running host instance.
          "--setenv"
          "NIXOS_XDG_OPEN_USE_PORTAL"
          "1"
          "--ro-bind"
          "${findGrepAliases}/bin"
          "/opt/find-grep/bin"
          # PATH is set via `profile` (not --setenv) so it prepends after FHS init.
          "--setenv"
          "ANTHROPIC_BASE_URL"
          "http://127.0.0.1:8787"
          "--setenv"
          "ANTHROPIC_AUTH_TOKEN"
          "dummy-key"
          "--setenv"
          "NO_PROXY"
          "127.0.0.1"
          "--setenv"
          "no_proxy"
          "127.0.0.1"

          # Override global git config log.showSignature=true so `git log`
          # output inside the sandbox isn't cluttered with "Good git signature"
          # lines (which pollute Claude's gitStatus context on startup).
          "--setenv"
          "GIT_CONFIG_COUNT"
          "1"
          "--setenv"
          "GIT_CONFIG_KEY_0"
          "log.showSignature"
          "--setenv"
          "GIT_CONFIG_VALUE_0"
          "false"
        ]
        ++ roBind [
          "\${HOME}/.gitconfig"
          "\${HOME}/.ssh"
          "\${HOME}/.gnupg"
          "\${HOME}/.tmux"
          "\${HOME}/.config"
          "\${HOME}/.themes"
          "\${HOME}/.bashrc"
          "\${HOME}/.bash_profile"
          "\${HOME}/.profile"
        ]
        ++ rwBind [
          "\${HOME}/repos"
          "\${HOME}/.cache"
          "\${HOME}/.npm"
          "\${HOME}/.cargo"
          "\${HOME}/.local"
          "\${HOME}/.claude"
          "\${HOME}/.claude.json"
          "\${HOME}/.claude.json.backup"
          "\${HOME}/.aws"
          "\${HOME}/.kube"
        ]
        ++ [
          "--tmpfs"
          "/run"
        ]
        ++ roBind [
          "/run/current-system"
          "/run/booted-system"
          "/run/wrappers"
          "/run/systemd"
        ]
        ++ rwBind [
          "/run/podman"
        ]
        ++ roBind [
          "/run/blkid"
        ]
        ++ rwBind [
          "/run/dbus"
        ]
        ++ [
          "--dir"
          "/run/user"
        ]
        ++ rwBind [
          "/run/user/$_run_uid"
        ]
        ++ roBind [
          "/run/last-user-input"
        ]
        ++ [
          "--dir"
          "/run/agenix"
        ]
        ++ roBind [
          "/run/agenix/pushover-token"
          "/run/agenix/anthropic-api-key"
          "/var/lib/mitmproxy-credential-proxy/mitmproxy-ca-cert.pem"
        ]
        # NOTE: Do NOT bind /etc wholesale here. The FHS env creates a
        # writable tmpfs at /etc so containerInit can generate ld.so.conf
        # and run ldconfig. A --ro-bind-try /etc /etc would override that
        # tmpfs and break startup. The FHS env already selectively binds
        # the important /etc entries (passwd, group, hosts, resolv.conf,
        # shells, fonts, ssl/certs, pam.d, localtime, etc.).
        ++ roBind [
          "/etc/binfmt.d"
          "/etc/bluetooth"
          "/etc/brave"
          "/etc/chromium"
          "/etc/containers"
          "/etc/geoclue"
          "/etc/NetworkManager"
          "/etc/nixos"
          "/etc/secureboot"
          "/etc/ssh"
          "/etc/stylix"
          "/etc/subgid"
          "/etc/subuid"
          "/etc/sway"
          "/etc/udisks2"
          "/etc/X11"
          "/etc/xdg"
          "/etc/Yubico"
          "/etc/zfs"
        ];
      };

      llmSummarize = pkgs.callPackage ../llm-tools/llm-summarize { };

      claudeNotifyHook = pkgs.stdenv.mkDerivation {
        pname = "claude-notify-hook";
        version = "1.0.0";

        src = ./scripts;

        buildInputs = [
          pkgs.bash
          pkgs.jaq
        ];

        installPhase = ''
          mkdir -p $out/bin

          substitute $src/notify-hook.sh $out/bin/claude-notify-hook \
            --replace "@jaq@" "${pkgs.jaq}/bin/jaq" \
            --replace "@llm-summarize@" "${llmSummarize}/bin/llm-summarize"

          chmod +x $out/bin/claude-notify-hook
        '';
      };

      claudeSessionSummary = pkgs.callPackage ./session-summary {
        inherit claude-code-sandboxed;
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

          cp $src/check-background-work.sh $out/bin/check-background-work
          chmod +x $out/bin/check-background-work

          substitute $src/wmab.sh $out/bin/wmab \
            --replace "@jaq@" "${pkgs.jaq}/bin/jaq"
          chmod +x $out/bin/wmab
        '';
      };

      claude-wrapper = pkgs.writeShellScriptBin "claude-wrapper" ''
        ${claude-code-sandboxed}/bin/claude --dangerously-skip-permissions "$@"
        exit_code=$?

        # Opt-out for automated/scripted invocations
        [[ -n "''${CLAUDE_NO_SUMMARY:-}" ]] && exit "$exit_code"

        git_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit "$exit_code"

        # .jack.yaml opt-out
        if [[ -f "$git_root/.jack.yaml" ]] \
           && grep -qE '^\s*session_summary\s*:\s*false' "$git_root/.jack.yaml"; then
          exit "$exit_code"
        fi

        # Find newest transcript
        claude_project_dir="$HOME/.claude/projects/$(echo "$git_root" | tr '/' '-')"
        [[ -d "$claude_project_dir" ]] || exit "$exit_code"
        transcript=$(ls -t "$claude_project_dir"/*.jsonl 2>/dev/null | head -1)
        [[ -n "$transcript" && -s "$transcript" ]] || exit "$exit_code"
        session_id=$(basename "$transcript" .jsonl)

        # Skip if in-progress (marker file)
        [[ -f "$git_root/.claude/background/$session_id" ]] && exit "$exit_code"

        # Skip if already summarized (session_id exists in a log file)
        if grep -rlF "\"$session_id\"" "$git_root/.claude/log/"*.json &>/dev/null; then
          exit "$exit_code"
        fi

        # Run summary detached
        ${claudeSessionSummary}/bin/claude-session-summary \
          --mode summarize \
          --transcript "$transcript" \
          --session-id "$session_id" \
          --project-dir "$git_root" &
        disown

        exit "$exit_code"
      '';

      claudeSkill = pkgs.callPackage ./skills/Skill { extract-frontmatter = extractFrontmatter; };

      claudePRD = pkgs.callPackage ./skills/PRD { };

      claudeAgentBrowser = pkgs.callPackage ./skills/AgentBrowser { };

      claudeDogfood = pkgs.callPackage ./skills/Dogfood { };

      claudeElectron = pkgs.callPackage ./skills/Electron { };

      claudeSlack = pkgs.callPackage ./skills/Slack { };

      agentBrowser = (pkgs.callPackage ./agent-browser { inherit versions; }).package;

      claudeNixOSBuild = pkgs.callPackage ./skills/NixOSBuild { homeDir = "/home/${config.username}"; };

      claudeSurprises = pkgs.callPackage ./skills/Surprises { inherit claude-code-sandboxed; };

      claudeKeePassXC = pkgs.callPackage ./skills/KeePassXC { };
      claudeGitHub = pkgs.callPackage ./skills/GitHub { };
      claudeGit = pkgs.callPackage ./skills/Git { };
      claudeTempScript = import ./skills/TempScript { };
      claudeSystemd = import ./skills/Systemd { };
      findGrepAliases = pkgs.callPackage ./find-grep { };
      claudeHeadroom = pkgs.callPackage ./headroom { inherit versions; };
      claudeBetterCcflare = pkgs.callPackage ./better-ccflare { inherit versions; };

      claude-unwrapped = pkgs.runCommand "claude-unwrapped" { } ''
        mkdir -p $out/bin
        ln -s ${nixpkgs-unstable.claude-code}/bin/claude $out/bin/claude-unwrapped
      '';

      locateHook = pkgs.writeShellApplication {
        name = "claude-locate-hook";
        runtimeInputs = [
          pkgs.jaq
          pkgs.gnugrep
        ];
        text = builtins.readFile ./claude-locate-hook.sh;
      };
    in
    lib.mkIf (config.deviceType != "remote-builder") {
      home-manager.users.${config.username} = {
        programs.zsh = {
          shellAliases = {
            cc = "claude-wrapper";
            una = "claude-una";
            q = "noglob claude-q";
            qq = "noglob claude-qq";
            qqq = "noglob claude-qqq";
            wmab = "noglob command wmab";
          };
        };

        home = {
          file = {
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

            ".headroom/.keep".text = "";
            ".local/share/better-ccflare/.keep".text = "";

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
                        # {
                        #   type = "command";
                        #   command = "${claudeNotifyHook}/bin/claude-notify-hook";
                        #   async = true;
                        #   timeout = 120;
                        # }
                        # TODO: re-enable surprise hook once stabilized
                        # {
                        #   type = "command";
                        #   command = "${claudeSurprises.hookPackage}/bin/claude-surprise-hook";
                        #   async = true;
                        #   timeout = 900;
                        # }
                      ];
                    }
                  ];

                  # Claude Code auto-converts Stop hooks into SubagentStop events
                  # when SubagentStop is unset, so each Task tool subagent finish
                  # would re-run the workmux + notify hooks. Register an explicit
                  # empty SubagentStop block to suppress that auto-conversion.
                  SubagentStop = [
                    {
                      matcher = ".*";
                      hooks = [ ];
                    }
                  ];

                  SessionEnd = [
                    {
                      hooks = [
                        {
                          type = "command";
                          command = "${claudeSessionSummary}/bin/claude-session-summary --mode hook";
                          async = true;
                          timeout = 300;
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

                  PreToolUse = [
                    {
                      matcher = "Bash|Grep|Glob";
                      hooks = [
                        {
                          type = "command";
                          command = "${locateHook}/bin/claude-locate-hook";
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
          // claudeAgentBrowser.homeFiles
          // claudeDogfood.homeFiles
          // claudeElectron.homeFiles
          // claudeSlack.homeFiles
          // claudeNixOSBuild.homeFiles
          // claudeSurprises.homeFiles
          // claudeKeePassXC.homeFiles
          // claudeGitHub.homeFiles
          // claudeGit.homeFiles
          // claudeTempScript.homeFiles
          // claudeSystemd.homeFiles;

          sessionVariables = {
            BETTER_CCFLARE_DB_PATH = "/home/${config.username}/.local/share/better-ccflare/better-ccflare.db";
            BETTER_CCFLARE_CONFIG_PATH = "/home/${config.username}/.local/share/better-ccflare/config.json";
          };

          activation.claudeJson = {
            after = [ "writeBoundary" ];
            before = [ ];
            data = ''
              CLAUDE_JSON="$HOME/.claude.json"
              EXA_TOKEN_PATH="${config.age.secrets.exa-token.path}"
              EXA_TOOLS="web_search_exa,get_code_context_exa,deep_researcher_start,deep_researcher_check"
              HOME_PROJECT="/home/${config.username}"

              if [[ ! -f "$CLAUDE_JSON" ]]; then
                echo '{}' > "$CLAUDE_JSON"
              fi

              TMP_JSON=$(${pkgs.coreutils}/bin/mktemp)
              trap '${pkgs.coreutils}/bin/rm -f "$TMP_JSON"' EXIT

              ${pkgs.jaq}/bin/jaq --arg home "$HOME_PROJECT" \
                '.projects //= {}
                 | .projects[$home] //= {}
                 | .projects[$home].hasTrustDialogAccepted = true' \
                "$CLAUDE_JSON" > "$TMP_JSON"
              ${pkgs.coreutils}/bin/cat "$TMP_JSON" > "$CLAUDE_JSON"

              if [[ -f "$EXA_TOKEN_PATH" ]]; then
                EXA_API_KEY="$(${pkgs.coreutils}/bin/cat "$EXA_TOKEN_PATH")"
                ${pkgs.jaq}/bin/jaq --arg key "$EXA_API_KEY" --arg tools "$EXA_TOOLS" \
                  '.mcpServers //= {} | .mcpServers.exa = {type: "http", url: "https://mcp.exa.ai/mcp?exaApiKey=\($key)&tools=\($tools)"}' \
                  "$CLAUDE_JSON" > "$TMP_JSON"
                ${pkgs.coreutils}/bin/cat "$TMP_JSON" > "$CLAUDE_JSON"
              fi
            '';
          };
        };

        systemd.user.services = claudeHeadroom.systemdServices // claudeBetterCcflare.systemdServices;

      };

      environment.systemPackages = [
        locateHook
        claudeNotifyHook
        claudeSurprises.hookPackage
        claudeShellScripts
        claudePRD.package
        claudeSkill.package
        agentBrowser
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
        claude-unwrapped
        claude-code-sandboxed
        claude-wrapper
        ccusage
        claudeHeadroom.package
        claudeBetterCcflare.package
        claudeSessionSummary
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
