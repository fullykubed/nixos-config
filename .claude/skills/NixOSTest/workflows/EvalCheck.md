# EvalCheck Workflow

Evaluate the full NixOS configuration to verify it resolves without errors. This catches missing attributes, type errors, assertion failures, and infinite recursion — all without building anything. Takes seconds.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Run Eval Check

```bash
nt-eval [hostname]
```

Hostname defaults to the current machine. The script evaluates the entire system configuration and returns the store path of the top-level derivation.

### 2. Interpret Results

| Output | Meaning |
|--------|---------|
| Store path (e.g., `/nix/store/...`) | Configuration evaluates successfully |
| `error: attribute '...' missing` | A referenced attribute doesn't exist |
| `error: assertion '...' failed` | An `assert` statement evaluated to false |
| `error: infinite recursion encountered` | Circular dependency in the configuration |
| `error: value is a ... while a ... was expected` | Type mismatch |
| `error: syntax error` | Syntax error — suggest running **SyntaxCheck** first |

### 3. Report Results

- **Success**: Report the store path and suggest running **DryBuild** as the next verification level.
- **Failure**: Show the error, identify the failing module if possible (the error trace usually includes file paths), and suggest a fix.

## Guidelines

- Eval check catches most configuration errors. If this passes, the config is likely correct — the remaining risk is that individual packages fail to build.
- This is the best general-purpose test. When unsure what test to run, start here.
