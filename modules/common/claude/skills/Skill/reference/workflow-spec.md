# Workflow Specification

Workflows are standalone markdown files that provide step-by-step instructions for Claude to follow. Each workflow handles one distinct task within a skill.

## File Format

```md
# <WorkflowName> Workflow

<Brief description of what this workflow accomplishes.>

## Prerequisites (optional)

<Conditions that must be met before starting.>

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. <Step Name>

<Detailed instructions for this step.>

### 2. <Next Step>

<Instructions with decision points, code examples, templates as needed.>

## Guidelines

- Key guidelines and best practices for this workflow
```

## Required Sections

| Section | Required | Purpose |
|---------|----------|---------|
| Title (`# <Name> Workflow`) | Yes | Identifies the workflow; must match the filename |
| Description | Yes | One-paragraph summary of what the workflow accomplishes |
| Prerequisites | No | Conditions that must be true before starting; redirect to another workflow if unmet |
| Workflow Steps | Yes | The numbered step-by-step process; must include the "MUST be followed" directive |
| Guidelines | Yes | Best practices and key principles that apply throughout the workflow |

## Conventions

| Convention | Description |
|------------|-------------|
| Steps are numbered | Each step has a clear number and name (e.g., `### 1. Research the CVE`) |
| Decision points use tables | Use `\| Situation \| Action \|` format for branching logic |
| Code examples use fenced blocks | Show exact commands, templates, and file formats |
| "MUST" indicates mandatory steps | Distinguish required actions from recommendations |
| Guidelines section at end | Summarize best practices that apply throughout |

## Writing Effective Steps

### Be Prescriptive

Tell Claude exactly what to do, not just what to consider. Claude follows instructions literally - vague guidance leads to inconsistent results.

**Good:**
```md
### 3. Create the Configuration File

Create `config.yaml` at the project root with this structure:
\```yaml
name: <project-name>
version: 1.0.0
\```
```

**Bad:**
```md
### 3. Configuration

You might want to create a config file. Consider what format works best.
```

### Include Decision Tables

When a step has branching logic, use tables to make the options explicit:

```md
| Situation | Action |
|-----------|--------|
| Package has upstream fix | Apply patch overlay |
| No fix available | Create whitelist entry |
| Fix requires breaking changes | Evaluate trade-offs with user |
```

### Show Exact Templates

When the workflow produces files, show the complete template with placeholder syntax:

```md
Create the file following this template:
\```md
---
name: <SkillName>
description: <Description>. USE WHEN <trigger conditions>.
---
\```
```

### Mark User Interaction Points

When a step requires user input or confirmation, make it explicit:

```md
**Ask the user:** "Which approach do you prefer: A or B?"

**Present to the user for confirmation** before proceeding to the next step.
```

### Use Prerequisites to Gate Entry

If a workflow depends on prior work, list prerequisites and redirect:

```md
## Prerequisites

Before proceeding, verify:
1. **CVE ID is known** - The user should provide a specific CVE
2. **Package is identified** - Know which package needs patching

If any prerequisite is missing, switch to the IdentifyCVE workflow first.
```

## Naming

- Workflow files live in `<skill>/workflows/`
- Filenames are PascalCase matching the workflow name: `CreateSkill.md`, `ResolveCVE.md`
- Names should be action-oriented: verb + noun (e.g., `CreatePRD`, `ReviewPatches`)
- The title inside the file must match: `# CreateSkill Workflow`

## Linking from SKILL.md

Every workflow must be linked in the SKILL.md routing table:

```md
| Workflow | Trigger Words | When to Use |
|----------|---------------|-------------|
| [CreateSkill](./workflows/CreateSkill.md) | "create", "new" | User wants to create a new skill |
```

The link path is relative to SKILL.md: `./workflows/<Name>.md`
