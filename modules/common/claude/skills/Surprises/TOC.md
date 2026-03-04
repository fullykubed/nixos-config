# Surprises/

Documentation surprise reviewer skill for fixing documentation discrepancies discovered by the surprise hook.

- `SKILL.md` — Skill definition with Review and Fix workflows for managing documentation surprises.
- `default.nix` — Nix derivation building CLI scripts and deploying skill files and agents.
- `agents/` — Custom subagent definitions for surprise review and investigation.
- `hooks/` — Stop hook script that extracts Read file paths from the transcript and forks a surprise-reviewer agent.
- `scripts/` — CLI tools for listing and reading surprise files.
- `workflows/` — Step-by-step procedure for fixing a recorded documentation surprise.
