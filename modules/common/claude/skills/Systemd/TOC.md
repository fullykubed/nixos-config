# Systemd/

Diagnostic skill for querying systemd journal logs, inspecting service and unit state, analyzing boot performance, and reviewing timer schedules.

- `SKILL.md` — Skill definition with YAML frontmatter; routes to the Diagnose workflow based on arguments.
- `workflows/` — Workflow documents for each diagnostic scenario.
  - `Diagnose.md` — Structured diagnostic covering failed units, journal queries, service status, boot analysis, and timer state.
