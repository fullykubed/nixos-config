# AgentBrowser/

Browser automation skill using the agent-browser CLI (Rust CLI + Node.js daemon with Playwright).

- `SKILL.md` — Skill definition with CLI commands (open, snapshot, click, fill, screenshot, eval, wait, close) and workflow routing.
- `default.nix` — Deploys skill files to `~/.claude/skills/AgentBrowser/` via homeFiles.
- `workflows/` — Step-by-step procedures for using AgentBrowser.
- `reference/` — Detailed reference documentation for commands, snapshot refs, and session management.
