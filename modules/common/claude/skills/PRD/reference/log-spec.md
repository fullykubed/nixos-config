# Implementation Log Specification

The implementation log (`log.md`) tracks all completed implementation work for a PRD. It is located at `.claude/prds/[prd_name]/log.md`.

## Format

```md
# Implementation Log

## [Task Name] - [Timestamp]

**Status**: Completed

### Summary
<Brief description of what was implemented>

### Changes Made
- `path/to/file.ext` - Description of change
- `path/to/another.ext` - Description of change

### Notes
<Any important decisions, deviations from spec, or context for future tasks>

---

## [Previous Task Name] - [Earlier Timestamp]
...
```

## Rules

- New entries are added at the **top** of the log (reverse chronological order)
- Each entry corresponds to a completed task from `tasks.yaml`
- The timestamp should use ISO 8601 format: `YYYY-MM-DD HH:MM`
- The "Changes Made" section should list every file that was created, modified, or deleted
