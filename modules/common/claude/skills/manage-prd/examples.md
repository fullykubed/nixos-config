# manage-prd Examples

## Example 1: List all PRDs

**User**: `/manage-prd`

**Assistant**:
```bash
claude-list-prds
```
```json
[
  {"name": "user-auth", "status": "in-progress", "completed": 2, "total": 5},
  {"name": "dark-mode", "status": "draft", "completed": 0, "total": 3},
  {"name": "api-refactor", "status": "complete", "completed": 4, "total": 4}
]
```

"You have 3 PRDs:
- **user-auth**: In progress (2/5 tasks completed)
- **dark-mode**: Draft (0/3 tasks completed)
- **api-refactor**: Complete (4/4 tasks completed)

What would you like to do?"

---

## Example 2: Check specific PRD status

**User**: `/manage-prd user-auth`

**Assistant**:
```bash
claude-task-status user-auth
```
```json
{"draft": 1, "defined": 2, "completed": 2, "total": 5}
```

"PRD 'user-auth' status:
- 2 tasks completed
- 2 tasks defined (ready to implement)
- 1 task still in draft (needs spec)

What would you like to do?
1. Plan the draft task
2. Work on defined tasks
3. Review the PRD"

---

## Example 3: Plan all draft tasks

**User**: "Plan all the draft tasks for user-auth"

**Assistant**:
```bash
claude-research-status user-auth
```
```json
{"draft": 0, "complete": 3, "total": 3}
```

"All research questions are answered. Checking draft tasks..."

```bash
claude-list-draft-tasks user-auth
```
```json
[
  {"name": "Add session management", "description": "Handle user sessions", "spec": "specs/add-session-management.md", "parent": null}
]
```

"There is 1 draft task that needs a spec:
- **Add session management**: Handle user sessions

Would you like me to generate the task specification?"

**User**: "Yes, go ahead"

**Assistant**:
"Spawning subagent to create the spec..."

Spawns: `/plan-prd-task user-auth "Add session management"`

---

## Example 4: Work on a PRD

**User**: "Work on user-auth"

**Assistant**:
```bash
claude-task-status user-auth
```
```json
{"draft": 0, "defined": 2, "completed": 2, "total": 4}
```

"All tasks are defined. Reading tasks.yaml to identify defined tasks..."

Reads `log.md` if exists for prior context.

"Starting implementation. Working on 'Implement login endpoint'..."

Spawns: `/work-prd-task user-auth "Implement login endpoint"`

When subagent returns, updates `log.md`:
```md
# Implementation Log

## Implement login endpoint - 2024-01-15 14:30

**Status**: Completed

### Summary
Created POST /api/auth/login endpoint with email/password validation.

### Changes Made
- `src/api/auth.ts` - Added login route handler
- `src/middleware/auth.ts` - Created authentication middleware
- `tests/auth.test.ts` - Added login endpoint tests

### Notes
Used bcrypt for password hashing as specified in constraints.

---
```

Continues to next task...

---

## Example 5: PRD with incomplete prerequisites

**User**: "Work on dark-mode"

**Assistant**:
```bash
claude-task-status dark-mode
```
```json
{"draft": 3, "defined": 0, "completed": 0, "total": 3}
```

"The PRD 'dark-mode' has 3 draft tasks but no defined tasks. All tasks need specs before implementation can begin.

Would you like me to plan the draft tasks first? This will create detailed specifications for each task."

---

## Example 6: Resume work after interruption

**User**: "Continue working on user-auth"

**Assistant**:
Reads `log.md`:
```md
## Implement login endpoint - 2024-01-15 14:30
**Status**: Completed
...
```

"I see 'Implement login endpoint' was completed. Checking remaining tasks..."

```bash
claude-task-status user-auth
```
```json
{"draft": 0, "defined": 1, "completed": 3, "total": 4}
```

"1 task remaining: 'Add password reset flow'. Continuing implementation..."

Spawns: `/work-prd-task user-auth "Add password reset flow"`
