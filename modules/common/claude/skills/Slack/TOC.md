# Slack/

Slack workspace automation skill using `agent-browser` browser automation.

- `SKILL.md` — Skill definition for interacting with Slack workspaces: checking unreads, sending messages, searching conversations, and extracting data.
- `default.nix` — Nix packaging: deploys skill files to `~/.claude/skills/Slack/` via home-manager.
- `reference/` — Reference documentation for common Slack operations.
  - `slack-tasks.md` — Task-by-task reference for Slack automation: unreads, channel navigation, messaging, search, and data extraction.
