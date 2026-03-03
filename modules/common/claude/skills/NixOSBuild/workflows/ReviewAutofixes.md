# ReviewAutofixes Workflow

Structured review of all `NixOSBuild AUTOFIX` blocks in the worktree. Approved fixes have their AUTOFIX comments stripped. Rejected fixes enter a rework loop where the user directs changes until satisfied.

## Context

The Build workflow automatically applies and commits fixes without waiting for approval — the `# NixOSBuild AUTOFIX` comment block marks code that was applied automatically and has not yet been reviewed by a human. This workflow does not gate or block the Build workflow in any way. It is a separate, on-demand process the user runs whenever they want to catch up on reviewing accumulated autofixes. Fixes may have been committed minutes or weeks ago.

When the user approves a fix here, the AUTOFIX comment is stripped — signaling that a human has reviewed and accepted the code. When the user rejects a fix, they direct how it should be reworked.

---

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Initialize

1. **Get worktree** from skill arguments. Ask if missing.
2. **Set worktree path**: `@home@/repos/nixos-config/<worktree>/`
3. **Verify worktree exists**. If not, list available worktrees and ERROR:
   ```bash
   git -C @home@/repos/nixos-config/main worktree list
   ```

---

### 2. Discover All Autofixes

1. **Search the worktree** for every `# NixOSBuild AUTOFIX` marker in Nix files:
   ```bash
   rg -n '# NixOSBuild AUTOFIX' @home@/repos/nixos-config/<worktree>/ --glob '*.nix'
   ```

2. **If no markers found**, report "No NixOSBuild AUTOFIX blocks found in worktree — nothing to review" and exit.

3. **For each marker**, read the surrounding code to extract the full autofix block. An autofix block consists of:
   - The `# NixOSBuild AUTOFIX` comment line
   - All subsequent comment lines (`# Package name:`, `# Error details:`, `# Fix explanation:`)
   - The Nix code that implements the fix — everything following the comment block up to the next AUTOFIX marker, the next non-autofix override/block, or the end of the enclosing expression

4. **Build a fix list** — for each autofix block, record:
   - **File path** — absolute path to the file
   - **Line range** — start and end line numbers of the entire block (comments + code)
   - **Package name** — from the `# Package name:` comment line
   - **Error details** — from the `# Error details:` comment line
   - **Fix explanation** — from the `# Fix explanation:` comment line
   - **Code** — the full autofix block (comments + Nix code)

5. **Report to user:**
   ```
   Found <N> autofix(es) to review in worktree: <worktree>
   ```

---

### 3. Review Each Fix

For each fix in the list (in file order), present it to the user for approval:

1. **Show the fix** — display the fix number, file, line range, and full code:
   ```
   ─────────────────────────────────────────────────────────────────────────────
   Fix <i>/<N>: <package_name>
   File: <file_path>:<start_line>-<end_line>
   ─────────────────────────────────────────────────────────────────────────────

   Error:  <error_details>
   Fix:    <fix_explanation>

   Code:
   ```
   Then show the autofix block by reading the relevant lines from the file.

2. **Ask the user** using AskUserQuestion:
   - Question: `Approve fix <i>/<N>: <package_name> — <brief_fix_explanation>?`
   - Options:
     - **Approve** — Keep the fix code, remove the AUTOFIX comment
     - **Reject** — Rework this fix

3. **Handle response:**
   - **Approve**: Mark this fix as approved. Continue to next fix.
   - **Reject**: Ask the user what should be changed about this fix. Apply their requested changes to the code. After changes are complete, re-show the updated code and ask again (Approve or Reject). Repeat until the user approves or explicitly asks to remove the fix entirely.

---

### 4. Apply Decisions

After all fixes have been reviewed:

1. **Strip AUTOFIX comments from approved fixes** — for each approved fix, remove the `# NixOSBuild AUTOFIX` comment block (the `# NixOSBuild AUTOFIX` line, `# Package name:` line, `# Error details:` line, and `# Fix explanation:` line). Keep the Nix code itself intact. Work in reverse line-number order within each file so that removals don't shift line numbers of subsequent edits.

2. **After editing each file**, verify it is still valid Nix:
   ```bash
   nix-instantiate --parse @home@/repos/nixos-config/<worktree>/<relative_file_path> > /dev/null 2>&1
   ```
   If the parse fails, undo and retry more carefully.

3. **Run lint** on the final state:
   ```bash
   cd @home@/repos/nixos-config/<worktree> && pre-commit run -a
   ```
   Fix any lint failures before proceeding.

---

### 5. Commit Changes

1. **Stage affected files** (specific files, not `git add -A`):
   ```bash
   git -C @home@/repos/nixos-config/<worktree> add <file1> <file2> ...
   ```

2. **Commit** with a message summarizing the review:
   ```bash
   git -C @home@/repos/nixos-config/<worktree> commit -m "$(cat <<'EOF'
   fix(<scope>): review <N> NixOSBuild autofixes

   Approved:
     - <package_1>: <brief_fix_1>
     - <package_2>: <brief_fix_2>

   Reworked:
     - <package_3>: <what_was_changed>
   EOF
   )"
   ```

3. **If commit fails** (lint hook): fix issues, re-stage, create a NEW commit (never `--amend`).

---

### 6. Report Summary

```
=============================================================================
AUTOFIX REVIEW COMPLETE
=============================================================================

Worktree: <worktree>

Reviewed: <N> fix(es)
  Approved: <M>
  Reworked: <R>

Approved fixes:
  - <package_1>: <brief_fix_1>
  - <package_2>: <brief_fix_2>

Reworked fixes:
  - <package_3>: <what_was_changed>

Commit: <commit_hash> <commit_subject>

Next steps:
  Run `un` to activate the configuration
=============================================================================
```

If any fixes were reworked, warn:
```
WARNING: Reworked fixes may re-introduce build errors. Consider running
/NixOSBuild <hostname> <worktree> to verify the build still succeeds.
```

---

## Guidelines

- Present fixes one at a time — never batch all fixes into a single approval question
- Show enough surrounding context for the user to understand each fix in isolation
- When a fix is rejected, always ask what should be changed before modifying anything — never silently remove a fix
- The reject→rework loop continues until the user approves or explicitly asks to remove the fix entirely
- On approval, strip the entire `# NixOSBuild AUTOFIX` comment block (all 4 lines) but keep the Nix code
- Work in reverse line-number order within each file so edits don't shift subsequent line numbers
- When editing one fix in a file with multiple fixes, take care not to damage other fixes in the same file
