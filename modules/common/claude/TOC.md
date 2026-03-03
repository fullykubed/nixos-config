# claude/

NixOS module integrating Claude Code with skills, shell scripts, and shared specifications.

- `default.nix` — Main NixOS/home-manager module that packages scripts, integrates skills, and deploys Claude Code configuration.
- `CLAUDE.md` — Project-level instructions for Claude Code covering workspace setup, vulnerability management, and CVE patching.
- `commands/` — Slash-command definitions for Claude Code (e.g., `/rebase`).
- `scripts/` — Shell scripts for terminal productivity and Claude Code integration hooks.
- `specs/` — Shared specification files and JSON schemas referenced by skills.
- `skills/` — Reusable skill packages providing domain-specific workflows and tooling.
