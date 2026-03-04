# scripts/

Shell scripts for terminal productivity and Claude Code integration.

- `q.sh` — Quick terminal prompt using Opus with WebSearch; returns concise answers rendered with Glow.
- `qq.sh` — Code research prompt using Sonnet with Exa code context tool for API docs and examples.
- `qqq.sh` — Deep research prompt using Sonnet with Exa deep researcher for comprehensive synthesis.
- `una.sh` — Invokes the NixOSBuild skill to auto-build and fix the current worktree for the detected hostname.
- `notify-hook.sh` — Listens to Claude Code event hooks and sends desktop notifications on build completion or conversation stop.
- `extract-conversation.sh` — Parses Claude Code conversation JSON and extracts user prompts and AI responses.
- `ai-commit-msg` — Shared helper that reads a diff from stdin and outputs a conventional commit message via Claude. Used by `ai-commit`, `ai-amend`, and `ai-reword`.
- `ai-commit` — Generates conventional commit messages for staged changes, runs pre-commit hooks in parallel, and opens editor for review. Supports `-y` flag to skip editor.
- `ai-amend` — Folds staged changes into an existing commit (HEAD or by SHA) and regenerates the message with Claude. Supports `-y` flag to skip editor.
- `ai-reword` — Rewrites a commit message by SHA using Claude, handling both HEAD and non-HEAD commits via rebase. Supports `-y` flag to skip editor.
- `ai-rebase` — Rebases onto a target branch with automatic Claude Code conflict resolution on failure.
- `ai-squash-commits` — Squashes a range of commits into one and generates a new message via `ai-reword`. Supports `-y` flag to skip editor.
