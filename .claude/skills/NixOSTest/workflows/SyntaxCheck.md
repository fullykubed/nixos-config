# SyntaxCheck Workflow

Instantly parse `.nix` files to catch syntax errors without evaluating anything. This is the fastest possible feedback — it runs in milliseconds.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Identify Target Files

Determine which files to check:

| Situation | Action |
|-----------|--------|
| User specified a file | Pass it as an argument |
| User specified a module directory | Pass all `.nix` files in that directory |
| No file specified | Pass no arguments (script auto-detects changed files from `git diff`) |

### 2. Run Syntax Check

```bash
nt-syntax [file ...]
```

The script parses each file with `nix-instantiate --parse` and reports OK/FAIL per file. With no arguments it checks all `.nix` files changed since HEAD.

### 3. Report Results

- **All passed**: Report success and suggest running **EvalCheck** as the next verification level.
- **Failures**: The script shows the exact error output including line and column numbers — highlight these for the user.

## Guidelines

- This check only catches syntax errors (missing semicolons, unmatched brackets, etc.) — it does NOT catch type errors, missing attributes, or evaluation failures.
- Files that import other files will still parse successfully even if the imported file doesn't exist.
- This is the first step in the feedback ladder: SyntaxCheck → EvalCheck → DryBuild → FullBuild.
