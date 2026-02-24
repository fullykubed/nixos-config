# CreateSkill Workflow

This workflow guides you through creating a new Claude Code skill from scratch.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Gather the Skill's Purpose

Ask the user to describe what the skill should do. Get a clear understanding of:

**Questions to ask:**
- What domain does this skill cover? (e.g., security, deployment, testing)
- What tasks should the skill handle?
- How many distinct workflows does it need?

**Follow-up as needed:**
- Clarify scope boundaries (what's in vs out)
- Identify if this overlaps with existing skills (run `claude-Skill-list-skills` to check)

### 2. Determine Skill Tier

Work with the user to decide where the skill should live:

| Tier | Choose When | Location |
|------|-------------|----------|
| **Repository-level** | Skill is specific to this repo or project | `.claude/skills/<SkillName>/` |
| **System-level** | Skill should be available in all projects | `modules/common/claude/skills/<SkillName>/` |

**Decision guidance:**
- Does the skill reference repo-specific files or conventions? → Repository-level
- Is the skill a general development capability? → System-level
- When in doubt: Start at repository-level; promote to system-level later

### 3. Choose the Skill Name

The name must be:
- **PascalCase** (e.g., `CodeReview`, `Deploy`, `TestRunner`)
- **Concise** but descriptive (1-2 words preferred)
- **Unique** among existing skills

Confirm the name with the user before proceeding.

### 4. Design the Workflows

For each workflow the skill needs:

1. **Name** - PascalCase, action-oriented (e.g., `CreatePRD`, `ResolveCVE`)
2. **Trigger words** - Words in user requests that indicate this workflow
3. **Purpose** - One sentence describing when to use it
4. **Steps** - High-level outline of the workflow's process

Present the workflow design as a routing table for user approval:

```md
| Workflow | Trigger Words | When to Use |
|----------|---------------|-------------|
| [Workflow1](./workflows/Workflow1.md) | "word1", "word2" | Description |
```

### 5. Create the Directory Structure

Create the skill directory with required subdirectories:

```bash
mkdir -p <skill-path>/{workflows,reference}
```

Only create `scripts/`, `schemas/`, or `hooks/` directories if the skill actually needs them.

### 6. Write the SKILL.md

Create the main skill definition file following this template:

Ask the user if the skill should use a specific model. If so, it MUST be a model alias: `opus`, `sonnet`, or `haiku`. Full model IDs (e.g. `claude-opus-4-6`) are not allowed — aliases ensure skills always use the latest version of a model tier. Omit the `model` field entirely to inherit the session's current model.

```md
---
name: <SkillName>
description: <Description>. USE WHEN <trigger conditions>.
model: <optional - opus, sonnet, or haiku>
---

You manage <domain> through <brief description>. Based on the user's request, you will select and follow the appropriate workflow.

## When Invoked

1. **Read Spec**: You MUST read the specification completely before proceeding:
   @./reference/<spec-file>.md

2. **Gather Context**: <How to assess current state>

3. **Determine Intent**: Analyze the user's request to identify:
   - <Key question 1>
   - <Key question 2>
   - Look for trigger words from the Workflow Routing table

4. **Select Workflow**: Select the appropriate workflow:
   1. <Decision 1> → **Workflow1**
   2. <Decision 2> → **Workflow2**
   3. When in doubt: Ask the user which workflow they want to use.

5. **Execute Workflow**: Report to the user "Running <workflow-name> using the <SkillName> skill..." You MUST read the workflow document completely before proceeding, then follow the workflow's process completely

6. **Report Results**: Summarize what was accomplished and suggest next steps

## Workflow Routing

| Workflow | Trigger Words | When to Use |
|----------|---------------|-------------|
| [Workflow1](./workflows/Workflow1.md) | "word1", "word2" | Description |

## Reference

- [Specification](./reference/<spec-file>.md)
```

**Important patterns to follow:**
- The `@./reference/<file>.md` syntax tells Claude to read the file when the skill is invoked
- Workflow links use relative paths: `./workflows/<Name>.md`
- The "When Invoked" section is the entry point logic - keep it clear and sequential

### 7. Write the Workflow Files

For each workflow, create a file at `<skill-path>/workflows/<WorkflowName>.md`.

Each workflow MUST follow this structure:

```md
# <WorkflowName> Workflow

<Brief description of what this workflow accomplishes.>

## Prerequisites (optional)

<Conditions that must be met before starting this workflow.>

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. <Step Name>

<Detailed instructions.>

### 2. <Next Step>

<Instructions with decision points, examples, templates.>

## Guidelines

- <Key guideline 1>
- <Key guideline 2>
```

**Writing effective workflow steps:**

| Practice | Description |
|----------|-------------|
| Be prescriptive | Tell Claude exactly what to do, not just what to consider |
| Include decision tables | Use `\| Situation \| Action \|` format for branching logic |
| Show exact commands | Include code blocks with actual commands to run |
| Provide templates | Show the exact format of files to create |
| Mark mandatory steps | Use "MUST" for required actions, "should" for recommendations |
| Number every step | Steps must be numbered for sequential execution |

### 8. Write Reference Documents (if needed)

Create reference files for:
- **Specifications** - Define file formats and structures the skill operates on
- **CLI tool documentation** - Document available CLI commands
- **Templates** - Reusable templates referenced by workflows

Place all reference files in `<skill-path>/reference/`.

### 9. Write CLI Scripts (if needed)

If the skill needs CLI tools for querying state or performing operations:

1. Create scripts in `<skill-path>/scripts/`
2. Output JSON for machine-readable results
3. Follow the naming convention: `claude-<SkillName>-<script-name>`

**Script implementation differs by tier:**

| Tier | Dependencies | Example |
|------|-------------|---------|
| **Repository-level** | Use tools directly from `PATH` (e.g., `jq`, `yq`) | `jq -r '.name' file.json` |
| **System-level** | Use `@tool@` substitution patterns for Nix dependency injection | `@jq@ -r '.name' file.json` |

**Do NOT use `@tool@` substitution in repository-level scripts** - they are not built by Nix and the patterns will not be resolved.

**For system-level skills only:** Register scripts in `modules/common/claude/default.nix`:
- Create a derivation following the `claudeSkillScripts` or `claudeTaskScripts` pattern
- Use `substitute` to replace `@tool@` patterns with pinned Nix store paths
- Add the derivation to `environment.systemPackages`

### 10. Validate the Skill

Before completing, verify:

1. **SKILL.md** has valid YAML front matter with `name` and `description`
2. **Model ID** (if set) is an allowed alias or full model ID per the Skill Specification
3. **Workflow routing table** links match actual workflow files
4. **Every linked workflow file** exists and follows the required structure
5. **Reference files** linked via `@` syntax exist
6. **Scripts** (if any) are executable and use the correct pattern for their tier
7. **No circular references** between workflows

### 11. Confirm with User

Present the completed skill to the user:

1. Show the directory structure created
2. Summarize each workflow's purpose
3. List any CLI tools that were created
4. Note if `default.nix` changes are needed (system-level skills)
5. Suggest testing the skill by invoking it

## Guidelines

- **Prefer deterministic scripts**: Whenever a workflow step involves querying state, validating data, or performing a repeatable action, implement it as a CLI script rather than relying on Claude to do it ad-hoc. Scripts produce consistent results regardless of context window or model behavior
- **Follow existing patterns**: Study the PRD and CVE skills as references for style and structure
- **Keep workflows focused**: Each workflow should handle one distinct task
- **Be prescriptive in workflows**: Claude follows instructions literally - vague guidance leads to inconsistent results
- **Start minimal**: Create the core workflows first; add reference docs and scripts only when needed
- **Name consistently**: PascalCase for directories, workflows, and skill names throughout
- **Test invocation**: After creating a skill, test it by asking Claude to use it
