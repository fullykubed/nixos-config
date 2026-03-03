# NixOSBuild/

Build automation skill that builds NixOS systems and iteratively fixes errors until the build succeeds.

- `SKILL.md` — Skill definition taking hostname and worktree arguments; routes to the Build workflow.
- `default.nix` — Nix derivation building shell scripts and reference docs with path substitutions.
- `reference/` — Error-specific handler docs and build tooling reference for the build-fix loop.
- `scripts/` — Build attempt tracking scripts for history, deduplication, and retry limits.
- `workflows/` — The core build-fix loop procedure.
