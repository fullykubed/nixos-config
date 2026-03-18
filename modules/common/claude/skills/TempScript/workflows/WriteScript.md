# WriteScript Workflow

Write an executable temp script to `.claude/tmp/` so the user can perform a multi-step action by running a single command.

## When to Use

Use this workflow instead of printing multi-step instructions whenever Claude needs the user to:
- Run more than one command in sequence
- Perform an action that involves pipes, loops, or conditionals
- Execute steps that depend on each other (e.g., capture output, then use it)

Do NOT use this workflow when:
- A single one-liner command suffices — just tell the user the command directly
- The action is purely informational (no commands to run)

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Determine the Script Contents

Identify every command the user needs to run. Consider:

| Concern | Action |
|---------|--------|
| Commands depend on each other | Chain with `&&` or use variables to pass state |
| A command might fail | Add `set -euo pipefail` and meaningful error messages |
| User needs to supply values | Use positional arguments (`$1`, `$2`) or clearly marked variables at the top of the script |
| Commands need elevated privileges | Avoid `doas` if at all possible. When unavoidable, prefix only the specific commands that need it — never run the entire script as root. Scope privileges to the narrowest command possible |

### 2. Verify Dependencies Are Available

Before writing the script, check that every executable it will use is available on the system. Run `command -v <executable>` for each one.

| Result | Action |
|--------|--------|
| All executables found | Proceed to step 3 |
| Missing, project has `flake.nix` with devShell | Investigate adding the package to the dev shell (see **Dev shell first** below) |
| Missing, no dev shell or not appropriate for dev shell | Add a `nix shell` shim in the script (see **nix shell shim** below) |
| Missing executable is not packaged | Stop and tell the user what's missing before writing anything |

**Dev shell first**: If the project uses Nix flakes with `nix develop`, check whether the missing tool belongs in the dev shell rather than shimmed into a one-off script. Read the `flake.nix` (and any `devshell.nix` or similar it imports) to understand how packages are added, then propose adding the executable there. This is the preferred approach — it makes the tool available to the whole project permanently. Only fall back to a shim if the tool is truly specific to this one script and doesn't belong in the dev shell.

**nix shell shim**: If the dev shell approach doesn't apply, add a preamble that makes the tool available at runtime:

```bash
# Ensure required tools are available
PATH="$(nix shell nixpkgs#<package> --command sh -c 'echo $PATH'):$PATH"
```

Only use this for one or two missing tools. If many are missing, tell the user to install them instead.

### 3. Write the Script

Write the script to `.claude/tmp/` in the project root using the following conventions (include `nix shell` shims from step 2 if needed):

- **Directory**: `.claude/tmp/` (create it if it doesn't exist)
- **Filename**: A short, descriptive kebab-case name with `.sh` extension (e.g., `setup-db.sh`, `migrate-data.sh`)
- **Shebang**: Always start with `#!/usr/bin/env bash`
- **Strict mode**: Always include `set -euo pipefail` on the second line
- **Comments**: Add a one-line comment at the top describing what the script does
- **Make executable**: Use the Bash tool to `chmod +x` the script after writing it

Template:

```bash
#!/usr/bin/env bash
set -euo pipefail
# <One-line description of what this script does>

<commands>
```

### 4. Tell the User to Run It

After writing the script, tell the user:

1. What the script does (one sentence)
2. The exact command to run it, e.g.:

```
.claude/tmp/setup-db.sh
```

3. If the script takes arguments, show the usage with example values

## Guidelines

- Keep scripts minimal — only include commands necessary for the task
- Do not add interactive prompts or confirmations unless the action is destructive
- If a script is only useful once, that's fine — `.claude/tmp/` is gitignored and ephemeral
- Prefer absolute paths inside scripts when referencing project files to avoid working-directory surprises
- If the user needs to review or modify values before running, put those values in clearly labeled variables at the top of the script
