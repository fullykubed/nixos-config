# PRD/

Product requirements management skill for creating, planning, and implementing PRDs.

- `SKILL.md` — Skill definition with three workflows (CreatePRD, PlanPRD, WorkPRD); uses Opus model.
- `default.nix` — Nix derivation building scripts with tool substitutions and exporting validation hooks.
- `agents/` — Custom subagent definitions for research and implementation tasks.
- `hooks/` — Post-edit validation hooks enforcing YAML schema compliance.
- `reference/` — Specification docs for PRD format, tasks, logging, and available CLI tools.
- `schemas/` — JSON Schema files for validating task and research YAML structures.
- `scripts/` — CLI tools for listing PRDs, querying task status, and managing research questions.
- `workflows/` — Step-by-step procedures for creating, planning, and implementing PRDs.
