# scripts/

CLI tools for listing PRDs, querying task status, and managing research questions.

- `list-prds.sh` — List all PRDs in `.claude/prds/` with status summaries.
- `task-status.sh` — Query task status for a given PRD (completed, pending, in-progress).
- `update-task-status.sh` — Update a task's status with schema validation.
- `list-prd-draft-tasks.sh` — List incomplete (draft) tasks in a PRD.
- `list-defined-tasks.sh` — List all defined tasks with descriptions.
- `get-task.sh` — Retrieve a full task definition including spec file and dependencies.
- `get-unanswered-research.sh` — List research questions that still need answers.
- `research-status.sh` — Get research completion percentage and unanswered question count.
