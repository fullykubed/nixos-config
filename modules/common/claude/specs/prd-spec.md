# PRD

PRD files describe a concrete objective and are a mechanism for collaboration between you and the user.
These files follow these rules:

- Open PRDs can be found under `.claude/prds` in the repository root.

- Every directory under `.claude/prds` is an open PRD. The PRD name is the directory name. For example,`.claude/prds/[prd_name]/PRD.md`.

- `PRD.md` files **MUST** have the following structure.

  ```md
  # [PRD Name]

  ## Objective

  <User-provided description of the objective. Ask clarifying questions to refine if needed.>

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

  - `[file_name_1]` - (Edit) Brief description of why this file is relevant (e.g., Contains the main component for this feature).
  - `[file_name_2]` - (Create) Brief description (e.g., API route handler for data submission).
  - `[file_name_3]` - (Delete) Brief description (e.g., Utility functions needed for calculations).

  ## Discussion

  <Clarifying questions you might have for the user>

  ### [Agent-provided question title]

  _[Fully specified question]_

  [User-provided answer]

  ### [Another Agent-provided question title]

  _[Another fully specified question]_

  [Another user-provided answer]
  ```

- Tasks are defined in a separate `tasks.yaml` file in the PRD directory (e.g., `.claude/prds/[prd_name]/tasks.yaml`).

  - The schema for `tasks.yaml` is defined in @~/.claude/specs/tasks.schema.json.
  - Top-level tasks **MUST** be worked sequentially. Subtasks can be worked in parallel.
  - Each task without subtasks must have an associated spec file (defined in the `spec` field) that provides detailed context for the subagent.

- Research questions can optionally be defined in a `research.yaml` file in the PRD directory (e.g., `.claude/prds/[prd_name]/research.yaml`).

  - The schema for `research.yaml` is defined in @~/.claude/specs/research.schema.json.
  - Each question has a `text` field and a `mode` field (`answer` or `deep-research`).
  - Use `deep-research` mode sparingly for questions with potentially many valid answers.
  - Answers and citations are populated by the exa MCP server.

- Any relative paths contained in the PRD file are relative from that specific PRD file, **NOT** another package directory or the repository root.

- If temporary files are needed, **ALWAYS store them in the PRD's directory (example: `.claude/prds/[prd]/some_file.md`)**.
