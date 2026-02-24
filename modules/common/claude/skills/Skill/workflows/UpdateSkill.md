# UpdateSkill Workflow

This workflow guides you through modifying an existing Claude Code skill.

## Prerequisites

Before proceeding, verify:
1. **Skill exists** - Run `claude-Skill-list-skills` to confirm the skill is present
2. **Skill is identified** - Know which skill to update (by name or directory)

If the skill doesn't exist, switch to the CreateSkill workflow.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Identify the Skill

Run `claude-Skill-skill-info <skill-name>` to get the current state of the skill:
- Current workflows
- Reference documents
- Scripts
- Schemas

Read the skill's SKILL.md completely to understand its current structure.

### 2. Determine the Update Type

Identify what the user wants to change:

| Update Type | Description | Files Affected |
|-------------|-------------|----------------|
| **Add workflow** | Create a new workflow file | `workflows/<Name>.md`, `SKILL.md` routing table |
| **Modify workflow** | Change steps in an existing workflow | `workflows/<Name>.md` |
| **Update routing** | Change trigger words or decision tree | `SKILL.md` |
| **Add reference** | Add a new reference document | `reference/<name>.md`, `SKILL.md` reference section |
| **Add script** | Add a new CLI tool | `scripts/<name>.sh`, `default.nix` (if system-level) |
| **Rename skill** | Change the skill's name | All files (directory rename + content updates) |
| **Change tier** | Move between repo-level and system-level | Directory move + `default.nix` changes |

If the update type is unclear, ask the user to clarify.

### 3. Execute the Update

Follow the appropriate section below based on update type.

#### 3A. Add Workflow

1. **Design the workflow** with the user:
   - Name (PascalCase, action-oriented)
   - Trigger words
   - Purpose
   - Step outline

2. **Create the workflow file** at `<skill-path>/workflows/<WorkflowName>.md` following the standard structure:
   ```md
   # <WorkflowName> Workflow

   <Description>

   ## Workflow Steps

   These workflow steps MUST be followed exactly as written.

   ### 1. <Step>
   ...

   ## Guidelines
   ...
   ```

3. **Update SKILL.md** routing table to include the new workflow:
   - Add row to the Workflow Routing table
   - Update the "Select Workflow" decision tree in "When Invoked"
   - Add to File Structure if applicable

#### 3B. Modify Workflow

1. **Read the current workflow** completely
2. **Identify specific changes** with the user
3. **Apply changes** while preserving:
   - The numbered step structure
   - The "These workflow steps MUST be followed exactly as written" directive
   - The Guidelines section
4. **Check SKILL.md** - Update trigger words or routing if the workflow's scope changed

#### 3C. Update Routing

1. **Read current SKILL.md** completely
2. **Modify the Workflow Routing table** - Update trigger words and descriptions
3. **Update the decision tree** in "When Invoked" → "Select Workflow"
4. **Verify** all workflow links still point to existing files

#### 3D. Add Reference Document

1. **Create the reference file** at `<skill-path>/reference/<name>.md`
2. **Add `@` reference** in SKILL.md if it should be auto-loaded:
   ```md
   @./reference/<name>.md
   ```
3. **Add link** in the Reference section of SKILL.md
4. **Update workflows** that should reference the new document

#### 3E. Add Script

1. **Create the script** at `<skill-path>/scripts/<name>.sh`
2. **Follow conventions**:
   - `#!/usr/bin/env bash` and `set -euo pipefail`
   - Use `@tool@` substitution patterns
   - Output JSON for machine-readable results
   - Include usage message on wrong arguments
3. **For system-level skills**: Update `default.nix`:
   - Add `substitute` command in the appropriate derivation's `installPhase`
   - Ensure the derivation is in `environment.systemPackages`
4. **Document the script** in the skill's `reference/cli-tools.md`

#### 3F. Rename Skill

1. **Rename the directory** from old name to new name
2. **Update SKILL.md** front matter: `name` field
3. **Update all internal references** (workflow links, `@` references)
4. **Update script names** if they follow `claude-<SkillName>-*` pattern
5. **For system-level skills**: Update `default.nix` derivation paths
6. **Search for external references** to the old name in CLAUDE.md or other skills

#### 3G. Change Tier

**Promoting to system-level (repo → system):**
1. Move `<repo>/.claude/skills/<Name>/` → `modules/common/claude/skills/<Name>/`
2. Add script derivation to `default.nix` (if scripts exist)
3. Add derivation to `environment.systemPackages`
4. Remove from repo-level `.claude/skills/`

**Demoting to repo-level (system → repo):**
1. Move `modules/common/claude/skills/<Name>/` → `.claude/skills/<Name>/`
2. Remove derivation from `default.nix`
3. Remove from `environment.systemPackages`

### 4. Validate Consistency

After making changes, verify:

1. **SKILL.md routing table** matches actual workflow files in `workflows/`
2. **All `@` references** point to existing files
3. **All workflow links** in the routing table are valid
4. **Script names** follow the `claude-<SkillName>-<name>` convention
5. **Front matter** `name` matches directory name
6. **No orphaned files** - Every workflow/reference file is linked from SKILL.md

### 5. Confirm with User

Present the changes:

1. List files that were created, modified, or deleted
2. Summarize what changed and why
3. Note if `default.nix` needs to be rebuilt (`nixos-rebuild switch`)
4. Suggest testing the updated skill

## Guidelines

- **Prefer deterministic scripts**: When adding or modifying functionality, implement repeatable actions (state queries, validation, data transformation) as CLI scripts rather than relying on Claude to perform them ad-hoc. Scripts produce consistent results regardless of context window or model behavior
- **Preserve existing structure**: Don't reorganize files unless explicitly asked
- **Update all references**: When renaming or moving, check every file for stale references
- **Keep routing table in sync**: The SKILL.md routing table is the source of truth for workflow discovery
- **Test after changes**: Suggest the user invoke the skill to verify it works
- **Minimize disruption**: Prefer surgical edits over rewriting entire files
