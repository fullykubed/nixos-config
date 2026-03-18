# Skill Specification

Skills are structured packages of instructions that teach Claude Code how to perform domain-specific tasks through well-defined workflows.

## Directory Structure

Every skill follows this directory layout:

```
<SkillName>/                # PascalCase directory name
├── SKILL.md                # Required: Main skill definition
├── default.nix             # System-level only: Nix packaging and home-manager integration
├── workflows/              # Required: At least one workflow
│   ├── <Workflow1>.md      # PascalCase workflow files
│   └── <Workflow2>.md
├── reference/              # Optional: Reference documents
│   └── *.md
├── scripts/                # Optional: CLI scripts
│   └── *.sh
├── schemas/                # Optional: JSON schemas for validation
│   └── *.schema.json
├── hooks/                  # Optional: Validation hooks
│   └── *.sh
└── agents/                 # Optional: Custom subagent definitions
    └── *.md
```

## SKILL.md Format

The SKILL.md file is the entry point for a skill. It has two parts: YAML front matter and a markdown body.

### YAML Front Matter

```yaml
---
name: my-skill
description: What this skill does. USE WHEN the user wants to...
---
```

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `name` | Yes | — | Display name and `/slash-command`. Lowercase letters, numbers, and hyphens only (max 64 characters) |
| `description` | Yes | — | What the skill does and when to use it. Claude uses this to decide when to auto-load the skill. **Must contain "USE WHEN"** (validated by hook) |
| `argument-hint` | No | — | Hint shown during autocomplete to indicate expected arguments (e.g. `[issue-number]`, `[filename] [format]`) |
| `disable-model-invocation` | No | `false` | Set to `true` to prevent Claude from auto-loading this skill. User must invoke manually with `/name` |
| `user-invocable` | No | `true` | Set to `false` to hide from the `/` menu. Only Claude can invoke it (background knowledge) |
| `allowed-tools` | No | — | Tools Claude can use without asking permission when this skill is active (e.g. `Read, Grep, Glob`) |
| `model` | No | session model | Model alias to use when this skill is active. See [Allowed Models](#allowed-models) |
| `context` | No | — | Set to `fork` to run in a forked subagent context |
| `agent` | No | `general-purpose` | Subagent type when `context: fork` is set. Built-in: `Explore`, `Plan`, `general-purpose`, or a custom agent from `.claude/agents/` |
| `hooks` | No | — | Hooks scoped to this skill's lifecycle. See Claude Code hooks documentation |

### Invocation Control

The `disable-model-invocation` and `user-invocable` fields control who can trigger a skill:

| Configuration | User can invoke | Claude can invoke | Use for |
|---------------|-----------------|-------------------|---------|
| (defaults) | Yes | Yes | General-purpose skills |
| `disable-model-invocation: true` | Yes | No | Side-effect workflows (deploy, commit) |
| `user-invocable: false` | No | Yes | Background knowledge and context |

### String Substitutions

Skills support placeholders in the markdown body that are resolved at invocation:

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments passed when invoking the skill. Appended as `ARGUMENTS: <value>` if not present in content |
| `$ARGUMENTS[N]` | Specific argument by 0-based index (e.g. `$ARGUMENTS[0]`) |
| `$N` | Shorthand for `$ARGUMENTS[N]` (e.g. `$0`, `$1`) |
| `${CLAUDE_SESSION_ID}` | Current session ID |
| `` !`command` `` | Runs a shell command at invocation time and replaces the placeholder with its output (dynamic context injection) |

### Allowed Models

The `model` field is validated by a PostToolUse hook. **Only model aliases are allowed** — full model IDs (e.g. `claude-opus-4-6`) are rejected. Aliases always resolve to the latest version of a model tier, so skills automatically benefit from model upgrades without manual updates.

| Alias | Description |
|-------|-------------|
| `opus` | Latest Opus model — complex reasoning, architecture, planning |
| `sonnet` | Latest Sonnet model — daily coding, balanced speed and capability |
| `haiku` | Latest Haiku model — fast, simple tasks |

**Rules:**
- You MUST use an alias (`opus`, `sonnet`, `haiku`) — full model IDs are blocked
- Omit the field entirely to inherit the session's current model
- The allowed list is maintained in `hooks/validate-skill.sh`

### Body Sections

The body MUST include these sections in order:

#### 1. Introduction

A one-sentence description of what the skill manages.

#### 2. When Invoked

Step-by-step instructions for what to do when the skill is triggered:

1. **Read references** - Load any required specification files using `@./reference/<file>.md` syntax
2. **Gather context** - Run CLI tools or read files to understand current state
3. **Determine intent** - Analyze the user's request against trigger words
4. **Select workflow** - Decision tree mapping intent to workflow
5. **Execute workflow** - Read and follow the selected workflow completely
6. **Report results** - Summarize what was accomplished

#### 3. Workflow Routing

A table with columns: Workflow (linked), Trigger Words, When to Use.

```md
| Workflow | Trigger Words | When to Use |
|----------|---------------|-------------|
| [WorkflowName](./workflows/WorkflowName.md) | "word1", "word2" | Description |
```

#### 4. Reference (optional)

Links to reference documents and CLI tools.

## Workflow File Format

See the [Workflow Specification](./workflow-spec.md) for the complete workflow file format, required sections, conventions, and writing guidelines.

## Script Conventions

Scripts differ significantly between tiers. Repository-level scripts run directly; system-level scripts are built by Nix with dependency injection.

### Naming

Scripts are deployed as CLI tools with the naming pattern:

```
claude-<SkillName>-<script-name>
```

For example: `claude-Skill-list-skills`, `claude-PRD-task-status`

### Repository-level Scripts

Repository-level scripts run directly from the repo and must use tools available on `PATH`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Use tools directly from PATH - no substitution patterns
# Repo-level scripts assume standard tools are available (jq, yq, etc.)

# Output JSON for machine-readable results
# Use >&2 for error messages
```

### System-level Scripts

System-level scripts are built by Nix and use `@tool@` substitution patterns for pinned dependency paths:

```bash
#!/usr/bin/env bash
set -euo pipefail

# @tool@ patterns are replaced at build time by Nix
# @jaq@ → jaq binary path (JSON/YAML processor)
# @extract-frontmatter@ → helper to extract YAML front-matter from markdown

# Output JSON for machine-readable results
# Use >&2 for error messages
```

**Do NOT use `@tool@` substitution patterns in repository-level scripts.** They are only resolved during Nix builds and will fail at runtime in a repo context.

### Nix Integration (System-level skills only)

**No hardcoded user paths.** Any reference to the current user's home directory, username, or other user-specific values MUST use `@placeholder@` substitution (e.g., `@home@`) and be resolved at build time from the NixOS config. Never hardcode `/home/<username>` in scripts or markdown files. The main module passes these values via `callPackage` arguments (e.g., `homeDir = "/home/${config.username}"`), and the skill's `default.nix` substitutes them into both scripts and documentation at build time.

Each system-level skill that needs Nix packaging owns a `default.nix` in its skill directory. The file returns an attrset with up to three fields:

| Field | Required | Description |
|-------|----------|-------------|
| `package` | If scripts exist | The `mkDerivation` that builds CLI scripts |
| `hooks` | If hooks exist | Claude Code hook entries (e.g., `hooks.PostToolUse`) |
| `homeFiles` | Yes | home-manager `home.file` entries that deploy skill files to `~/.claude/` |

The main `modules/common/claude/default.nix` imports each skill via `callPackage` and merges their exports:

```nix
# In the let block:
claudeMySkill = pkgs.callPackage ./skills/MySkill { };

# homeFiles merged into home.file with //:
home.file = { /* global entries */ }
  // claudeMySkill.homeFiles;

# hooks concatenated:
PostToolUse = claudeMySkill.hooks.PostToolUse ++ ...;

# package added to systemPackages:
environment.systemPackages = [ claudeMySkill.package ... ];
```

#### Skill `default.nix` patterns

**Skill with scripts, hooks, and agents** (e.g., PRD):

```nix
{ pkgs, ... }:
let
  package = pkgs.stdenv.mkDerivation {
    pname = "claude-<skillname>-scripts";
    version = "1.0.0";
    src = ./scripts;
    buildInputs = [ pkgs.bash pkgs.jaq ];
    installPhase = ''
      mkdir -p $out/bin
      substitute $src/my-script.sh "$out/bin/claude-<SkillName>-my-script" \
        --replace "@jaq@" "${pkgs.jaq}/bin/jaq"
      chmod +x "$out/bin/claude-<SkillName>-my-script"
    '';
  };
in
{
  inherit package;
  hooks.PostToolUse = [
    {
      matcher = "Edit|Write";
      hooks = [
        { type = "command"; command = "${package}/bin/claude-<SkillName>-validate"; }
      ];
    }
  ];
  homeFiles = {
    ".claude/skills/<SkillName>" = { source = ./.; recursive = true; };
    ".claude/agents/my-agent.md" = { source = ./agents/my-agent.md; };
  };
}
```

**Skill with user-path substitution in docs** (e.g., NixOSBuild):

```nix
{ pkgs, homeDir, ... }:
let
  skillDocs = pkgs.stdenv.mkDerivation {
    pname = "claude-<skillname>-docs";
    version = "1.0.0";
    src = ./.;
    installPhase = ''
      mkdir -p $out
      cp -r . $out/
      rm -f $out/default.nix
      find $out -name '*.md' -exec sed -i 's|@home@|${homeDir}|g' {} +
    '';
  };
in
{
  homeFiles = {
    ".claude/skills/<SkillName>" = { source = skillDocs; recursive = true; };
  };
}
```

Markdown files use `@home@` as a placeholder for the user's home directory. The `callPackage` call passes `homeDir` from the NixOS config:

```nix
claudeMySkill = pkgs.callPackage ./skills/MySkill { homeDir = "/home/${config.username}"; };
```

#### Registering in the main `default.nix`

After creating the skill's `default.nix`, add it to `modules/common/claude/default.nix`:

1. Add a `callPackage` (or `import` for skills without packages) in the `let` block
2. Merge `homeFiles` into `home.file` with `//`
3. If the skill has hooks, concatenate them into the relevant hook list
4. If the skill has a package, add it to `environment.systemPackages`

#### Agents

Skills can include custom subagent definitions in an `agents/` subdirectory. These are deployed to `~/.claude/agents/` via `homeFiles` so Claude Code discovers them globally:

```nix
homeFiles = {
  ".claude/skills/MySkill" = { source = ./.; recursive = true; };
  ".claude/agents/my-agent.md" = { source = ./agents/my-agent.md; };
};
```

## Reference Document Conventions

- Reference files live in the `reference/` directory
- They are loaded via `@./reference/<file>.md` in SKILL.md
- Use them for specifications, templates, and documentation that workflows reference
- Keep them focused: one concern per file

## Schema Conventions

- JSON Schema files validate structured data (YAML, JSON) used by the skill
- Place in `schemas/` directory
- Reference from validation hooks

## Hook Conventions

- Hooks are shell scripts that run automatically (e.g., PostToolUse)
- Place in `hooks/` directory within the skill
- For system-level skills, export hook entries in the skill's `default.nix` under `hooks.<EventName>` — the main module merges them into `settings.json`
- Must exit 0 on success; output a JSON `{"decision": "block", "reason": "..."}` to block an action
