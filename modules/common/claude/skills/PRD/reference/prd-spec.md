# PRD Specification

PRD files describe a concrete objective and are a mechanism for collaboration between you and the user.

## Format

```md
# [PRD Name]

## Objective

<User-provided description of the objective. Ask clarifying questions to refine if needed.>

## Motivation

<Why this objective matters. What problem does it solve? What value does it provide? What is the impact of not doing this?>

## Implementation Details

### Architecture

<A high-level description of how components will be structured and interact. Include diagrams if helpful.>

### Constraints

<A list of user-provided and AI-generated constraints for accomplishing the objective.>

- Concise, but precise description of the constraint (e.g., "Create new components in separate files")
- Concise, but precise description of another constraint (e.g., "Use Kobalte for the slider")

### Relevant Guides

<A list of guide files that are necessary to follow when accomplishing the objective.>

- `[/some/path]/CLAUDE.md`
- `[/some/other/path]/README.md`
- `[/some/path]/STYLEGUIDE.md`

### Relevant Files

<A list of files that are necessary to accomplishing the objective.>

| File | Action | Description |
|------|--------|-------------|
| `[file_name_1]` | Edit | Brief description (e.g., Contains the main component for this feature) |
| `[file_name_2]` | Create | Brief description (e.g., API route handler for data submission) |
| `[file_name_3]` | Delete | Brief description (e.g., Legacy file no longer needed) |
| `[file_name_4]` | Review | Brief description (e.g., Reference for existing patterns to follow) |

## Discussion

<Clarifying questions you might have for the user>

### [Agent-provided question title]

_[Fully specified question]_

[User-provided answer]

### [Another Agent-provided question title]

_[Another fully specified question]_

[Another user-provided answer]
```

## Rules

- Open PRDs can be found under `.claude/prds` in the repository root
- Every directory under `.claude/prds` is an open PRD; the PRD name is the directory name (e.g., `.claude/prds/[prd_name]/PRD.md`)
- Tasks are defined in a separate `tasks.yaml` file in the PRD directory (e.g., `.claude/prds/[prd_name]/tasks.yaml`)
  - Top-level tasks **MUST** be worked sequentially; subtasks can be worked in parallel
  - Each task without subtasks must have an associated spec file (defined in the `spec` field)
- Research questions can optionally be defined in a `research.yaml` file in the PRD directory
  - Each question has a `text` field and a `mode` field (`answer` or `deep-research`)
  - Use `deep-research` mode sparingly for questions with potentially many valid answers
  - Answers and citations are populated by the exa MCP server
- Any relative paths contained in the PRD file are relative from that specific PRD file, **NOT** another package directory or the repository root
- If temporary files are needed, **ALWAYS** store them in the PRD's directory (e.g., `.claude/prds/[prd]/some_file.md`)
