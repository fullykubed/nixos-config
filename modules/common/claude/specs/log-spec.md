# Implementation Log Specification

The implementation log (`log.md`) tracks all completed implementation work for a PRD. It is located at `.claude/prds/[prd_name]/log.md`.

## Purpose

- A running summary of what has been done
- Context for resuming work after interruptions
- A record of decisions made during implementation

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
- The "Notes" section should capture:
  - Deviations from the original spec (and why)
  - Decisions that might affect future tasks
  - Any blockers encountered and how they were resolved
  - Context that would help someone reviewing the work

## Example

```md
# Implementation Log

## Implement login endpoint - 2024-01-15 14:30

**Status**: Completed

### Summary
Created POST /api/auth/login endpoint with email/password validation and JWT token generation.

### Changes Made
- `src/api/auth/login.ts` - Created login route handler with bcrypt password verification
- `src/api/routes.ts` - Added /auth/login route
- `src/middleware/auth.ts` - Created JWT verification middleware
- `tests/api/auth.test.ts` - Added 4 test cases for login endpoint

### Notes
Used bcrypt with cost factor 12 as specified in constraints. JWT expiry set to 24 hours based on discussion question answer in PRD.

---

## Set up database schema - 2024-01-14 10:15

**Status**: Completed

### Summary
Created initial database schema for user authentication.

### Changes Made
- `prisma/schema.prisma` - Added User model with email, password_hash, created_at fields
- `prisma/migrations/001_init.sql` - Initial migration

### Notes
Added unique constraint on email field. Index on created_at for future query optimization.
```
