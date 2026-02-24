---
name: Skill
description: Create and manage Claude Code skills, including workflows, reference docs, and CLI scripts. USE WHEN the user wants to create a new skill, add workflows to an existing skill, or update skill definitions.
---

You manage Claude Code skills through their complete lifecycle. Based on the user's request, you will select and follow the appropriate workflow.

## When Invoked

1. **Read Skill Spec**: You MUST read the skill specification completely before proceeding:
   @./reference/skill-spec.md

2. **Gather Context**: Run `claude-Skill-list-skills` to see all existing skills and their current state.

3. **Determine Intent**: Analyze the user's request to identify:
   - Are they creating a new skill or modifying an existing one?
   - What specific action do they want (create, update, add workflow)?
   - Look for trigger words from the Workflow Routing table

4. **Select Workflow**: Select the appropriate workflow based on the user's intent and trigger words:
   1. Does the user want to create a new skill? → **CreateSkill**
   2. Does the user want to modify an existing skill? → **UpdateSkill**
   3. When in doubt: Ask the user which workflow they want to use.

5. **Execute Workflow**: Report to the user "Running <workflow-name> using the Skill skill..." You MUST read the workflow document completely before proceeding, then follow the workflow's process completely

6. **Report Results**: Summarize what was accomplished and suggest next steps

## Workflow Routing

| Workflow | Trigger Words | When to Use |
|----------|---------------|-------------|
| [CreateSkill](./workflows/CreateSkill.md) | "create", "new", "build", "add skill", "make" | User wants to create a new skill from scratch |
| [UpdateSkill](./workflows/UpdateSkill.md) | "update", "modify", "edit", "add workflow", "change", "refactor" | User wants to modify an existing skill's definition, workflows, or structure |

## File Structure

```
<repo>/
├── .claude/skills/                    # Repository-level skills
│   └── <SkillName>/
│       ├── SKILL.md                   # Main skill definition
│       ├── workflows/                 # Workflow files
│       │   └── <WorkflowName>.md
│       ├── reference/                 # Reference documents (optional)
│       │   └── *.md
│       ├── scripts/                   # CLI scripts (optional)
│       │   └── *.sh
│       ├── schemas/                   # JSON schemas (optional)
│       │   └── *.schema.json
│       └── hooks/                     # Validation hooks (optional)
│           └── *.sh
└── modules/common/claude/skills/      # System-level skills (NixOS module)
    └── <SkillName>/                   # Same structure as above
```

## Skill Tiers

| Tier | Location | Deployment | Use When |
|------|----------|------------|----------|
| **Repository-level** | `.claude/skills/` | Per-repo (checked in) | Skill is specific to one repository or project |
| **System-level** | `modules/common/claude/skills/` | Via home-manager to `~/.claude/skills/` | Skill should be available across all projects |

## Reference

- [Skill Specification](./reference/skill-spec.md)
- [Workflow Specification](./reference/workflow-spec.md)
- [CLI Tools](./reference/cli-tools.md)
