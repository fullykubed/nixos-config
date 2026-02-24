# CLI Tools

The following CLI tools are available across all workflows.

### `claude-Skill-list-skills`

Lists all skills from both repository-level (`.claude/skills/`) and system-level (`modules/common/claude/skills/`) locations. Returns JSON output.

```bash
claude-Skill-list-skills
# Output:
# [
#   {"name": "CVE", "directory": "CVE", "tier": "repo", "path": ".claude/skills/CVE", "description": "Identify, triage...", "workflow_count": 3, "workflows": ["IdentifyCVE", "ResolveCVE", "ReviewPatches"]},
#   {"name": "PRD", "directory": "PRD", "tier": "system", "path": "modules/common/claude/skills/PRD", "description": "Comprehensive PRD...", "workflow_count": 3, "workflows": ["CreatePRD", "PlanPRD", "WorkPRD"]},
#   ...
# ]
```

Each entry includes:
- `name` - Skill name from YAML front matter
- `directory` - Directory name
- `tier` - Either `repo` (repository-level) or `system` (system-level)
- `path` - Relative path to the skill directory
- `description` - Skill description from YAML front matter
- `workflow_count` - Number of workflow files
- `workflows` - List of workflow names

Use this to check for name conflicts before creating a new skill.

### `claude-Skill-skill-info <skill-name>`

Returns detailed JSON about a specific skill, including its workflows, reference documents, scripts, and schemas.

```bash
claude-Skill-skill-info CVE
# Output:
# {
#   "found": true,
#   "name": "CVE",
#   "description": "Identify, triage, and resolve CVE vulnerabilities...",
#   "model": "default",
#   "path": ".claude/skills/CVE",
#   "workflows": ["IdentifyCVE", "ResolveCVE", "ReviewPatches"],
#   "references": [],
#   "scripts": [],
#   "schemas": []
# }
```

If the skill is not found:
```bash
claude-Skill-skill-info NonExistent
# Output: {"error": "Skill 'NonExistent' not found", "found": false}
```
