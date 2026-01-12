# WorkPRD Workflow

This workflow guides you through implementing the tasks defined in a planned PRD.

## Prerequisites

IMPORTANT: You MUST verify the following before proceeding.

1. **Identify the correct PRD name**
   - If PRD name is specified, use that name
   - If PRD name is NOT specified:
     1. Run `claude-PRD-list-prds` to list available PRDs
     2. Present the list to the user with their statuses
     3. Ask which PRD to work on

2. **Verify the PRD is ready for implementation**

   Run the following checks:

   | Check | Command | Pass Criteria |
   |-------|---------|---------------|
   | All tasks defined | `claude-PRD-task-status [prd_name]` | `draft` == 0 and `defined` > 0 |
   | Research complete | `claude-PRD-research-status [prd_name]` | `draft` == 0 (or no research.yaml) |
   | Discussion answered | Read PRD.md | All questions have answers |

   If any check fails, inform the user and switch to the PlanPRD workflow.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Implement Task Plans

Once all tasks are defined, delegate implementation to subagents.

**Get defined tasks:**
```bash
claude-PRD-list-defined-tasks [prd_name]
```

**Launch subagents:**

For each defined task, use the Task tool to spawn a `prd-worker` subagent:

| Parameter | Value |
|-----------|-------|
| `subagent_type` | `"prd-worker"` |
| `prompt` | `"Implement the task at spec path: [spec_path]"` |
| `description` | `"Implement [task-name]"` |

**Example invocation:**

For a task with `spec_path: /home/user/prds/auth-feature/tasks/add-middleware.yaml`:

```
subagent_type: "prd-worker"
prompt: "Implement the task at spec path: /home/user/prds/auth-feature/tasks/add-middleware.yaml"
description: "Implement add-middleware"
```

**Execution order:**
- Top-level tasks MUST be worked sequentially (wait for completion before starting next)
- Subtasks within a parent can be launched in parallel

**Collect results:**

For each completed subagent:
1. If `status` is `completed`:
   - Update task status:
     ```bash
     claude-PRD-update-task-status [prd_name] "[task-name]" completed
     ```
   - Record the `summary` and `changes` for the log

2. If `status` is `blocked`:
   - Keep task status as `defined`
   - Document the `blockers` for user review

### 2. Update Documentation

After all tasks are complete, update codebase documentation as needed.

IMPORTANT: Follow any documentation guidelines defined in the codebase (e.g., CONTRIBUTING.md, style guides, CLAUDE.md).

**Documentation checklist:**

| Check | Action |
|-------|--------|
| **README** | Update if new features, setup steps, or usage patterns were added |
| **API docs** | Document new public functions, endpoints, or interfaces |
| **Inline comments** | Add comments for complex logic that isn't self-explanatory |
| **Configuration** | Document new environment variables or config options |
| **Examples** | Add usage examples for new functionality |

**Guidelines:**
- Focus on the **Why** and **intent**, not the What—code shows what it does, documentation explains why
- Only add documentation that provides value
- Keep documentation close to the code it describes
- Follow existing documentation patterns in the codebase
- Do not document obvious or self-explanatory code

### 3. Report Results

After all tasks are complete, provide the user with a summary of what was accomplished.

**Include in the report:**
- Total tasks completed vs blocked
- Files created, modified, and deleted
- Key decisions made during implementation
- Any blockers that need user attention

**Example:**

```
## Implementation Complete: [prd_name]

### Summary
- Tasks completed: 4/5
- Tasks blocked: 1

### Changes
- Created: `src/auth/middleware.ts`, `src/auth/types.ts`
- Modified: `src/routes/api.ts`, `src/config.ts`
- Deleted: `src/legacy/auth.ts`

### Key Decisions
- Used JWT instead of sessions for stateless auth
- Added rate limiting middleware to all protected routes

### Blockers
- Task "Add OAuth support": Missing OAuth credentials in environment
```

## Guidelines

- **Stay focused**: Only implement what specs describe
- **Follow constraints**: Technical constraints are requirements, not suggestions
- **Test thoroughly**: Complete all testing requirements before marking complete
- **Handle blockers**: Document issues rather than working around them incorrectly
- **Respect dependencies**: Verify dependent tasks are completed first
- **Preserve context**: Understand surrounding code before making changes
- **Update documentation**: Log entries are critical for tracking progress
