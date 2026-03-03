# Claude Code Architecture

Claude Code runs in a sandboxed environment with credentials injected at the network layer, skills and hooks managed as Nix derivations, and configuration generated declaratively by home-manager. This document explains the motivations behind each layer and how they fit together.

```
                           Shell Aliases
                      cc | q | qq | qqq | una
                               |
                               v
                        claude-wrapper
                  (--dangerously-skip-permissions)
                               |
                               v
              +------------------------------------+
              |  buildFHSEnvBubblewrap Sandbox     |
              |                                    |
              |  Namespaces: PID, IPC, UTS         |
              |  Private /tmp (64 MB tmpfs)        |
              |  Hostname: claude-sandbox          |
              |                                    |
              |  RO mounts: .ssh .gitconfig .gnupg |
              |             .config .bashrc        |
              |  RW mounts: repos/ .cache/ .npm/   |
              |             .cargo/ .claude/ .aws/  |
              |             .kube/ .local/          |
              |                                    |
              |  HTTP_PROXY=127.0.0.1:8080         |
              |  HTTPS_PROXY=127.0.0.1:8080        |
              +---------------+--------------------+
                              |
              +---------------+--------------------+
              |               |                    |
              v               v                    v
        Anthropic API   Credential Proxy     MCP Servers
                        (127.0.0.1:8080)       (Exa)
                              |
                  +-----------+-----------+
                  |                       |
                  v                       v
           MITM intercept           TCP tunnel
         (configured domains)     (all other hosts)
                  |
                  v
          Inject auth header
          from agenix secret
```

**Entry point:** `modules/common/claude/default.nix`
**Credential proxy:** `modules/common/mitmproxy-credential-proxy/`

## Why a Sandbox?

Claude Code runs with `--dangerously-skip-permissions`, giving it unrestricted tool access. The bubblewrap FHS environment (`buildFHSEnvBubblewrap`) compensates by constraining what it can reach:

- **Namespace isolation** (PID, IPC, UTS) prevents Claude from seeing or signaling host processes. The hostname is set to `claude-sandbox` so scripts can detect they're inside the sandbox.
- **Selective bind mounts** give read-write access to working directories (`~/repos`, `~/.cache`, `~/.claude`) while keeping identity files (`.ssh`, `.gitconfig`, `.gnupg`) and shell config read-only.
- **Private `/tmp`** (64 MB tmpfs) prevents data leaking through temp files.
- **Forced proxy** via `HTTP_PROXY`/`HTTPS_PROXY` environment variables routes all outbound traffic through the credential proxy, so secrets never need to exist inside the sandbox.

The wrapper script (`claude-wrapper`) is the standard entry point — it runs the sandboxed binary with `--dangerously-skip-permissions --yes` and is what the `cc` alias invokes.

## Why a Credential Proxy?

The problem: Claude needs to authenticate with external APIs (GitHub, private registries, etc.), but passing tokens as environment variables or files inside the sandbox expands the attack surface. Instead, credentials are injected at the HTTP layer by a MITM proxy running outside the sandbox.

The proxy (`modules/common/mitmproxy-credential-proxy/`) is a TypeScript service (built with Bun + node-forge) that listens on `127.0.0.1:8080`. It handles HTTP CONNECT requests from the sandbox in two ways:

- **Mapped domains**: the proxy TLS-terminates using a forged certificate signed by a local CA, reads the decrypted HTTP request, injects the configured header from an agenix secret, and forwards upstream. The CA cert is added to the system trust store and bind-mounted into the sandbox.
- **Unmapped domains**: the proxy creates a direct TCP tunnel with no interception.

Credential mappings are a simple list in the Nix module — each entry specifies a domain, a header name, a value prefix, and a secret path. Currently GitHub (`api.github.com` -> `Authorization: token <secret>`) is the only mapping, but adding a new service means adding one more entry to the list. The real tokens never enter the sandbox.

## Skills

Skills package domain-specific workflows so Claude can be invoked for structured tasks. Each skill has a `SKILL.md` (front matter + routing table), one or more workflow files, and optional scripts, hooks, schemas, and reference docs.

There are two tiers:

- **System-level** (`modules/common/claude/skills/`) — packaged as Nix derivations with a `default.nix` that exports CLI scripts to `$PATH`, home-manager files to `~/.claude/skills/`, and PostToolUse hooks merged into `settings.json`. Scripts use `@placeholder@` substitution at build time so they reference exact Nix store paths for tools like `jq` and `yq`.
- **Repository-level** (`.claude/skills/`) — checked into the project repo, no Nix packaging, use whatever is on `$PATH`.

| Skill | What it does |
|-------|-------------|
| Skill | Meta-skill for creating and managing other skills |
| PRD | Product requirements lifecycle — research, planning, implementation. Defines custom subagents (`prd-researcher`, `prd-worker`) deployed to `~/.claude/agents/` |
| NixOSBuild | Iterative build-and-fix loop for NixOS configurations |
| DevBrowser | Headless Chromium automation via a CLI wrapping Playwright |

## MCP Servers

Exa is the only MCP server. It provides web search, code context lookup, and deep research tools used both in interactive sessions and by the quick-query scripts (`qq`, `qqq`) and the PRD researcher subagent.

The Exa API key is an agenix secret. A home-manager activation hook reads the decrypted token and writes the MCP server entry into `~/.claude.json` using `jq`. This keeps the key out of the Nix store and out of version control.

## Hooks

Hooks run shell commands on Claude Code lifecycle events. They serve two purposes: keeping the tmux status line in sync, and validating files after edits.

The system-level hooks (generated into `~/.claude/settings.json`):
- `Notification` / `UserPromptSubmit` / `Stop` events call `workmux set-window-status` to update the tmux window indicator (`waiting`, `working`, `done`), so when running multiple Claude sessions across worktrees you can see which ones need attention.
- `PostToolUse` events on `Edit|Write` trigger skill validation hooks (PRD schema validation, SKILL.md frontmatter validation). These are assembled by merging each skill package's hook exports.

## Shell Integration

Five aliases provide quick access from the terminal:

| Alias | Purpose |
|-------|---------|
| `cc` | Interactive Claude Code session (sandbox + auto-accept) |
| `q` | One-shot Opus answer with web search, rendered with glow |
| `qq` | Code research via Sonnet + Exa code context |
| `qqq` | Deep research via Sonnet + Exa deep researcher |
| `una` | NixOS build-and-fix for the current git worktree |

The `q`/`qq`/`qqq` scripts are thin wrappers that invoke `claude -p` with a specific model, allowed tools, and system prompt, then pipe through `glow` for terminal markdown rendering. `una` detects the worktree and hostname, then invokes the NixOSBuild skill.

Claude sessions are typically launched via `workmux`, which creates a tmux window with nvim, a Claude pane, and a shell. The lifecycle hooks keep the tmux status updated across all worktrees. `ccusage` provides a token burn-rate display in the Claude Code status bar.

## Secrets

Three agenix secrets support Claude Code:

| Secret | Why it exists |
|--------|--------------|
| `exa-token.age` | Exa API key. Injected into `~/.claude.json` at activation time. |
| `github-token.age` | GitHub token. Read at request time by the credential proxy and injected as an HTTP header. Never enters the sandbox. |
| `credential-proxy-ca-key.age` | CA private key for signing forged TLS certificates. Used by the proxy to MITM mapped domains. |

The Exa token flows through home-manager activation (decrypt -> read -> jq -> `~/.claude.json`). The GitHub token flows through the credential proxy at runtime (decrypt -> read on each CONNECT -> inject header). The CA key is copied into the proxy's state directory by the systemd `ExecStartPre` script.

## Key Files

| Path | Role |
|------|------|
| `modules/common/claude/default.nix` | Main module — sandbox, wrapper, settings, skills, secrets |
| `modules/common/claude/scripts/` | Shell scripts (q, qq, qqq, una, notify-hook) |
| `modules/common/claude/skills/` | System-level skill packages (Skill, PRD, NixOSBuild, DevBrowser) |
| `modules/common/mitmproxy-credential-proxy/` | Credential proxy module and TypeScript source |
