# RunChecks Workflow

Run the flake's checks output, which includes pre-commit hooks (nixfmt, statix, deadnix, gitleaks) and any other registered checks. This validates code quality and formatting without building the system.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Run Flake Checks

```bash
nt-check
```

This evaluates and builds all `checks.<system>` outputs, which currently includes `pre-commit-check` (nixfmt-rfc-style, statix, deadnix, gitleaks, check-bun-versions).

### 2. Interpret Results

| Output | Meaning |
|--------|---------|
| Silent success (no error output) | All checks passed |
| `nixfmt` error | Nix files need formatting — run `nix fmt` to fix |
| `statix` warning | Anti-pattern detected — review the suggestion |
| `deadnix` warning | Unused binding found — remove or prefix with `_` |
| `gitleaks` error | Potential secret detected in committed files |

### 3. Auto-fix Formatting (if applicable)

If the only failures are formatting issues, offer to fix them:

```bash
nix fmt
```

### 4. Report Results

- **All passed**: Report success.
- **Formatting issues only**: Report what was reformatted after running `nix fmt`.
- **Linter warnings**: List each warning with the file and line number. Suggest fixes.
- **Secret detection**: Flag the file and warn the user — do NOT commit secrets.

## Guidelines

- `nix flake check` evaluates ALL check outputs, not just linters. If VM tests or other checks are added to the flake in the future, this workflow will automatically include them.
- Formatting fixes (`nix fmt`) are safe to run automatically — they're deterministic and reversible.
- Statix and deadnix findings are advisory — discuss with the user before making changes, as some "unused" bindings may be intentional.
- This workflow does NOT require a hostname — checks are system-wide, not per-configuration.
