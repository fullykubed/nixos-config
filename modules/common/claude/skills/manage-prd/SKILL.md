---
name: manage-prd
description: Manages the full lifecycle of PRDs including creating, refining, working on, and reviewing them. Use when working with PRDs, checking PRD status, implementing PRD tasks, or managing multiple PRDs.
model: claude-opus-4-5-20251101
---

You manage the full lifecycle of PRDs (Product Requirements Documents) from creation through completion.

## PRD Specification

@~/.claude/specs/prd-spec.md

## Implementation Log Specification

@~/.claude/specs/log-spec.md

## CLI Tools

The following CLI tools are available for managing PRDs and tasks:

### `claude-list-prds`
Lists all PRDs with their status. Returns JSON output.

```bash
claude-list-prds
# Output: [{"name": "my-feature", "status": "in-progress", "completed": 3, "total": 5}, ...]
```

Statuses:
- `draft` - No tasks completed
- `in-progress` - At least one but not all tasks completed
- `complete` - All tasks completed
- `no-tasks` - No tasks.yaml or no tasks defined

### `claude-task-status <prd-name>`
Returns JSON describing task counts by status for a specific PRD.

```bash
claude-task-status my-feature
# Output: {"draft": 2, "defined": 3, "completed": 1, "total": 6}
```

### `claude-update-task-status <prd-name> <task-name> <new-status>`
Updates the status of a specific task.

```bash
claude-update-task-status my-feature "Implement API endpoint" defined
# Valid statuses: draft, defined, completed
```

### `claude-list-draft-tasks <prd-name>`
Lists all leaf tasks in draft status for a specific PRD.

```bash
claude-list-draft-tasks my-feature
# Output: [{"name": "Implement API endpoint", "description": "...", "spec": "specs/implement-api-endpoint.md", "parent": null}, ...]
```

### `claude-list-defined-tasks <prd-name>`
Lists all leaf tasks with `defined` status that are ready for implementation.

```bash
claude-list-defined-tasks my-feature
# Output: [{"name": "Implement API endpoint", "description": "...", "spec": "specs/implement-api-endpoint.md", "parent": null}, ...]
```

### `claude-get-task <prd-name> <task-name>`
Returns full task details including status, spec path, and file locations. Useful for checking task state without reading tasks.yaml.

```bash
claude-get-task my-feature "Implement API endpoint"
# Output:
# {
#   "name": "Implement API endpoint",
#   "description": "Create the login endpoint",
#   "status": "defined",
#   "spec": "specs/implement-api-endpoint.md",
#   "spec_path": ".claude/prds/my-feature/specs/implement-api-endpoint.md",
#   "spec_exists": true,
#   "parent": null,
#   "prd_name": "my-feature",
#   "prd_path": ".claude/prds/my-feature/PRD.md",
#   "log_path": ".claude/prds/my-feature/log.md",
#   "log_exists": true,
#   "found": true
# }
```

### `claude-research-status <prd-name>`
Returns JSON describing research question status for a specific PRD.

```bash
claude-research-status my-feature
# Output: {"draft": 1, "complete": 4, "total": 5}
```

A question is `complete` if it has an answer, `draft` otherwise.

## Available Actions

### 1. Create PRD
Use the `/create-prd <prd-name>` skill to create a new PRD through guided questions.

### 2. Plan PRD
Use the `/plan-prd <prd-name>` skill to analyze and plan an existing PRD.

### 3. Plan PRD Tasks
Define all draft tasks for a PRD by creating spec files for each.

**Prerequisites (ALL must pass before planning tasks):**
1. **All research questions must be answered** - Run `claude-research-status <prd-name>` and verify `draft` count is 0 (skip if no research.yaml exists)
2. **All discussion questions must be answered** - Read the PRD.md and verify every question in the Discussion section has an answer below it

If any prerequisite fails, suggest `/plan-prd <prd-name>` to address the gaps.

**Once prerequisites pass:**
1. Run `claude-list-draft-tasks <prd-name>` to get all draft tasks
2. **Ask the user for approval before proceeding** - List the draft tasks and confirm the user wants to generate specs for them
3. Once approved, for each draft task spawn a subagent to run `/plan-prd-task <prd-name> "<task-name>"`
4. Subagents can run in parallel since task specs are independent

### 4. Work on PRD
Implement the tasks defined in a PRD. **No approval needed - proceed immediately once prerequisites pass.**

**Prerequisites:** Run `claude-task-status <prd-name>` and verify `draft` count is 0. If draft tasks exist, suggest using action 3 (Plan PRD Tasks) first.

**Once prerequisites pass (do NOT ask for approval):**
1. Run `claude-list-defined-tasks <prd-name>` to get all tasks ready for implementation
2. Read `log.md` if it exists to understand prior work
3. Work on top-level tasks sequentially; subtasks can be worked in parallel
4. For each defined task:
   - Spawn a subagent to run `/work-prd-task <prd-name> "<task-name>"`
   - When subagent returns, update `log.md` with a summary of the completed work
5. Continue until all tasks are completed

## Instructions

When invoked, determine what the user wants to do:

1. **No specific action**: Run `claude-list-prds` to list all open PRDs and their status, then ask what action to take

2. **Specific PRD mentioned**: Run `claude-task-status <prd-name>` to show that PRD's details and ask what action to take

3. **Action specified**: Execute the requested action

## Working on a PRD

When implementing tasks:

### Step 1: Verify PRD is Complete

Verify the PRD is ready for task planning:

1. **Check research status** (if research.yaml exists):
   ```bash
   claude-research-status <prd-name>
   ```
   If `draft` > 0, research questions need answers.

2. **Check discussion questions**: Read the PRD.md and verify every question in the Discussion section has an answer below it.

3. **Check PRD fields**: Read the PRD.md and verify all required sections are fully filled out.

4. **Check tasks exist**:
   ```bash
   claude-task-status <prd-name>
   ```
   If `total` == 0, the PRD has no tasks defined.

If any check fails, suggest `/plan-prd <prd-name>` to complete the PRD first. Do not proceed.

### Step 2: Generate Task Definitions

Run `claude-task-status <prd-name>` to check task status.

If `completed` == `total`, all tasks are already complete. Inform the user and ask what they want to do (e.g., review, close, or add more tasks).

If `draft` == 0, all tasks are defined. Skip to Step 3.

If `draft` > 0, **you MUST ask the user for explicit approval** before generating task definitions. List the draft tasks and wait for user confirmation. Only after receiving approval, execute action 3 (Plan PRD Tasks) to spawn subagents that create spec files for each draft task. **Do NOT proceed without explicit user approval.**

### Step 3: Implement Tasks

**Do NOT ask for approval. Proceed immediately with implementation.** Once task specs are defined, begin implementing without waiting for user confirmation:

1. Run `claude-list-defined-tasks <prd-name>` to get all tasks ready for implementation
2. If `log.md` exists, read it to understand what has already been done
3. Work on top-level tasks sequentially; subtasks can be worked in parallel
4. For each defined task:
   a. Spawn a subagent to run `/work-prd-task <prd-name> "<task-name>"`
   b. When the subagent returns, **immediately update `log.md`**:
      - Add a new entry at the top of the file with the task name and timestamp
      - Include the summary of what was implemented (from subagent response)
      - List all files that were created/modified/deleted
      - Note any important decisions or context
   c. Continue to the next task
5. The subagent will:
   - Use `claude-get-task` to get task details and spec path
   - Read the spec file for detailed requirements
   - Implement the task following constraints
   - Update task status to `completed`
   - Report what was done

### Step 4: Review and Summarize

When all tasks are completed:

1. Read the full `log.md` file
2. Provide the user with a summary that includes:
   - Total number of tasks completed
   - High-level overview of what was implemented
   - List of all files created, modified, or deleted
   - Any important decisions or trade-offs made during implementation
   - Suggested next steps (e.g., testing, deployment, documentation)

## Progress Tracking

Use CLI tools to show PRD status:

```bash
claude-list-prds           # Overview of all PRDs
claude-task-status <prd>   # Detailed status for one PRD
```

For implementation history, read the `log.md` file:
```
.claude/prds/<prd-name>/log.md
```

## References

- [Usage Examples](./examples.md)
