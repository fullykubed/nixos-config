# work-prd-task Examples

## Example 1: Implement a specific task

**User**: `/work-prd-task user-auth "Implement login endpoint"`

**Assistant**:
1. Reads `.claude/prds/user-auth/tasks.yaml` - confirms task is `defined`
2. Reads `.claude/prds/user-auth/specs/implement-login-endpoint.md`
3. Reads `.claude/prds/user-auth/PRD.md` for overall context
4. Reads `.claude/prds/user-auth/log.md` - sees prior setup task completed
5. Reads files listed in spec's "Files to Modify"

"Implementing login endpoint according to spec..."

- Creates `src/api/auth/login.ts`
- Adds route to `src/api/routes.ts`
- Creates tests in `tests/api/auth.test.ts`

Verifies acceptance criteria:
- [x] POST /api/auth/login accepts email and password
- [x] Returns JWT token on success
- [x] Returns 401 on invalid credentials
- [x] Rate limited to 5 attempts per minute

```bash
claude-update-task-status user-auth "Implement login endpoint" completed
```

"**Task completed**: Implement login endpoint

**Files changed:**
- `src/api/auth/login.ts` - Created login handler
- `src/api/routes.ts` - Added /auth/login route
- `tests/api/auth.test.ts` - Added 4 test cases

**Acceptance criteria:** All 4 criteria verified"

---

## Example 2: Task with dependencies

**User**: `/work-prd-task user-auth "Add password reset flow"`

**Assistant**:
Reads spec and sees:
```md
### Related Tasks
- **Depends on**: "Implement email service" (must be completed first)
```

Reads tasks.yaml - finds "Implement email service" has status `completed`.

Reads log.md:
```md
## Implement email service - 2024-01-15 10:00
**Status**: Completed
### Summary
Set up SendGrid integration with templates...
```

"Dependency satisfied. Proceeding with password reset implementation using the email service..."

---

## Example 3: Task not ready (draft status)

**User**: `/work-prd-task dark-mode "Add theme toggle"`

**Assistant**:
Reads tasks.yaml - finds task has status `draft`:
```yaml
- name: Add theme toggle
  description: Add UI toggle for switching themes
  status: draft
  spec: specs/add-theme-toggle.md
```

"The task 'Add theme toggle' is still in draft status. It needs a detailed spec before implementation.

Run `/plan-prd-task dark-mode \"Add theme toggle\"` to create the spec first."

---

## Example 4: Task already completed

**User**: `/work-prd-task user-auth "Set up database schema"`

**Assistant**:
Reads tasks.yaml - finds task has status `completed`.

"The task 'Set up database schema' is already completed.

From the implementation log:
> Completed 2024-01-14: Created users table with email, password_hash, created_at fields...

Would you like to review the implementation or make changes?"

---

## Example 5: Implementation blocked

**User**: `/work-prd-task api-gateway "Add Redis caching"`

**Assistant**:
Reads spec and starts implementation...

"I've encountered a blocker:

**Issue**: The spec requires Redis connection, but no Redis configuration exists in the codebase. The spec's 'Technical Constraints' section references `config/redis.ts` which doesn't exist.

**Attempted**:
- Searched for existing Redis setup
- Checked environment configuration
- Reviewed related task specs

**Recommendation**:
Either add Redis configuration first, or update the spec to include Redis setup steps.

Task status remains `defined`. Please advise how to proceed."

---

## Example 6: Task with out-of-scope items

**User**: `/work-prd-task notifications "Implement push notifications"`

**Assistant**:
Reads spec:
```md
## Out of Scope
- Email notifications (separate task)
- SMS notifications (future PRD)
- Notification preferences UI (separate task)
```

Implements only push notifications...

"**Task completed**: Implement push notifications

**Files changed:**
- `src/services/push.ts` - Push notification service
- `src/api/notifications.ts` - Push registration endpoint

**Note**: As specified, email/SMS and preferences UI are out of scope for this task."

---

## Example 7: No PRD specified

**User**: `/work-prd-task`

**Assistant**:
```bash
claude-list-prds
```
```json
[
  {"name": "user-auth", "status": "in-progress", "completed": 2, "total": 5},
  {"name": "dark-mode", "status": "draft", "completed": 0, "total": 3}
]
```

"Which PRD would you like to work on?
- **user-auth**: 3 tasks remaining (2 defined, 1 draft)
- **dark-mode**: 3 tasks remaining (all draft - need specs first)"
