# plan-prd-task Examples

## Example 1: Plan a specific task

**User**: `/plan-prd-task my-feature "Implement API endpoint"`

**Assistant**:
1. Reads `.claude/prds/my-feature/PRD.md` for context
2. Reads `.claude/prds/my-feature/tasks.yaml` for task details
3. Explores relevant codebase files
4. Creates spec at `.claude/prds/my-feature/specs/implement-api-endpoint.md`
5. Runs `claude-update-task-status my-feature "Implement API endpoint" defined`

---

## Example 2: Plan a task from a specific PRD (task not specified)

**User**: `/plan-prd-task my-feature`

**Assistant**:
```bash
claude-list-draft-tasks my-feature
```
```json
[
  {"name": "Implement API endpoint", "description": "Create REST endpoint for user data", "parent": null},
  {"name": "Add validation", "description": "Validate request parameters", "parent": null}
]
```

"There are 2 draft tasks in my-feature. Which would you like to plan?"

**User**: "Implement API endpoint"

**Assistant**: Proceeds with planning...

---

## Example 3: No PRD or task specified

**User**: `/plan-prd-task`

**Assistant**:
```bash
claude-list-prds
```
```json
[
  {"name": "my-feature", "status": "draft", "completed": 0, "total": 3},
  {"name": "auth-system", "status": "in-progress", "completed": 2, "total": 5}
]
```

"Which PRD would you like to plan a task for?"

**User**: "my-feature"

**Assistant**:
```bash
claude-list-draft-tasks my-feature
```
```json
[
  {"name": "Implement API endpoint", "description": "Create REST endpoint for user data", "parent": null}
]
```

"There is 1 draft task. Would you like to plan 'Implement API endpoint'?"

---

## Example 4: Planning a subtask

**User**: `/plan-prd-task my-feature "Add input validation"`

**Assistant**:
```bash
claude-list-draft-tasks my-feature
```
```json
[
  {"name": "Add input validation", "description": "Validate user input fields", "parent": "Form handling"}
]
```

Notes that this is a subtask under "Form handling" parent task, includes this context in the spec file.

---

## Example 5: Task already defined

**User**: `/plan-prd-task my-feature "Implement API endpoint"`

**Assistant**:
Reads tasks.yaml and finds the task has status "defined".

"The task 'Implement API endpoint' is already defined. Its spec is at `.claude/prds/my-feature/specs/implement-api-endpoint.md`. Would you like to review or update the spec?"
