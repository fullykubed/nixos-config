# Task Spec Template

Each task without subtasks must have an associated spec file that provides detailed context for implementation.

## Format

```md
# [Task Name]

## Objective

<A clear, actionable statement of what this task should accomplish. Be specific about the expected outcome.>

## Context

<Background information the subagent needs to understand why this task exists and how it fits into the larger PRD objective.>

### Parent PRD

- **PRD**: [PRD Name]
- **PRD Path**: `.claude/prds/[prd_name]/PRD.md`

### Related Tasks

<List any tasks that this task depends on or that depend on this task.>

- **Depends on**: [Task name(s) that must be completed before this task]
- **Blocks**: [Task name(s) that cannot start until this task is complete]

## Acceptance Criteria

<A checklist of specific, measurable criteria that define when this task is complete.>

- [ ] Criterion 1: <Specific, verifiable condition>
- [ ] Criterion 2: <Specific, verifiable condition>
- [ ] Criterion 3: <Specific, verifiable condition>

## Implementation Notes

### Files to Modify

<List files that will need to be created, modified, or deleted.>

| File Path | Action | Description |
|-----------|--------|-------------|
| `path/to/file.ext` | Create/Edit/Delete | Brief description of changes |

### Technical Constraints

<Any technical requirements, limitations, or patterns that must be followed.>

- Constraint 1
- Constraint 2

### Relevant Code References

<Pointers to existing code that the subagent should review or use as reference.>

- `path/to/file.ext:line_number` - Description of what this code does
- `path/to/another/file.ext` - Description of relevance

### Code Examples

<Optional code snippets showing expected patterns, function signatures, or usage examples.>

## Testing Requirements

<How should the subagent verify their implementation is correct?>

- [ ] Test requirement 1
- [ ] Test requirement 2

## Out of Scope

<Explicitly list what this task should NOT do to prevent scope creep.>

- Item 1
- Item 2
```

## Rules

- Spec files are stored in the PRD's `specs/` directory (e.g., `.claude/prds/[prd_name]/specs/[task-name].md`)
- The spec file path is defined in the task's `spec` field in `tasks.yaml`
- Be thorough but focused - include enough detail for implementation without over-specifying
- Use concrete file paths and line numbers in code references
- Make acceptance criteria verifiable and specific
- Keep "Out of Scope" clear to prevent scope creep during implementation
- If a task is complex, consider breaking it into subtasks before creating the spec
