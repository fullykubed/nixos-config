# Fix Workflow

Fix a recorded documentation surprise by reading the surprise file, understanding the underlying issue, applying the recommended resolution, and deleting the surprise file on success.

## Prerequisites

- At least one surprise file must exist in `.claude/surprises/` in the main worktree
- If no surprises exist, report "No surprises to fix" and exit

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. List Open Surprises

Run `claude-Surprises-list` to show all open surprises as a JSON array. Present the list to the user in a readable format:

```bash
claude-Surprises-list
```

If the result is `[]`, report that there are no open surprises and stop.

### 2. Select a Surprise

Determine which surprise to fix:

| Situation | Action |
|-----------|--------|
| Surprise slug was passed as `$ARGUMENTS[0]` | Use that slug directly; verify it exists in the list |
| Multiple surprises exist and no argument given | Present the list and ask the user which one to fix |
| Only one surprise exists | Confirm with the user to fix it |

### 3. Read the Surprise

Run `claude-Surprises-get <slug>` to read the full surprise file content:

```bash
claude-Surprises-get <slug>
```

Parse the surprise to understand:
- **Category**: `stale-reference`, `incorrect-instruction`, `knowledge-gap`, `contradiction`, or `failed-action`
- **Sources**: The files where the issue originates
- **Expected**: What the documentation says or implies
- **Found**: The actual discrepancy
- **Recommended Resolution**: The suggested fix

### 4. Analyze the Category and Resolution

Based on the category, prepare your approach:

| Category | Fix Approach |
|----------|-------------|
| `stale-reference` | Update or remove the reference in the source doc; verify the correct path/name |
| `incorrect-instruction` | Fix the documented command, step, or instruction to match actual behavior |
| `knowledge-gap` | Add missing documentation to the appropriate file(s) |
| `contradiction` | Identify which doc is correct and update the incorrect one; or reconcile both |
| `failed-action` | Document in CLAUDE.md or relevant skill/workflow what should NOT be done and why |

Read all source files listed in the surprise frontmatter to understand the current state before making changes.

### 5. Attempt the Fix

Apply the fix based on the category analysis:

1. Read each source file mentioned in the surprise
2. Read any additional context files that are relevant (referenced modules, related docs, etc.)
3. Make the necessary edits using the Edit tool
4. Ensure the fix addresses the **Recommended Resolution** from the surprise

**For `stale-reference`**: Find the stale reference in the source doc and either update it to the correct path/name or remove it entirely. Verify the correct path exists before updating.

**For `incorrect-instruction`**: Correct the documented step, command, or path. Test commands in Bash if safe to do so.

**For `knowledge-gap`**: Add the missing documentation to the appropriate location. Follow existing documentation style and placement conventions.

**For `contradiction`**: Determine which source is authoritative (usually the one closer to the code), update the incorrect one, and note any necessary cross-references.

**For `failed-action`**: Add a note to the relevant doc (CLAUDE.md, skill workflow, or TOC) documenting the failed approach and what to do instead.

### 6. Verify the Fix

After applying the fix, verify it addresses the surprise:

1. Re-read the modified file(s) to confirm the change is correct
2. Check that the fix aligns with the **Recommended Resolution**
3. Verify no new contradictions or stale references were introduced by the edit
4. If the fix involved a command or path, confirm it is correct

**Ask yourself:** "If an AI agent or developer read this documentation now, would they encounter the same surprise?"

If the fix is incomplete or introduces new issues, iterate until the documentation is accurate.

### 7. Delete the Surprise File and Report

Once the fix is verified, delete the surprise file from the main worktree:

```bash
# Resolve the default branch worktree path
MAIN_WORKTREE=$(git-worktree-path)

# Delete the surprise file
rm "$MAIN_WORKTREE/.claude/surprises/<slug>.md"
```

Report the results to the user:
- What file was fixed
- What change was made
- That the surprise file has been deleted
- How many surprises remain (run `claude-Surprises-list` again to get the count)

## Guidelines

- Always read the source files before making any edits — understanding context prevents introducing new issues
- Prefer minimal, targeted edits that address exactly the documented discrepancy
- Do not "improve" documentation beyond what the surprise requires — stay focused on the specific issue
- If the recommended resolution is unclear or would require significant refactoring, ask the user for guidance before proceeding
- If investigation reveals the surprise is no longer valid (e.g., the issue was already fixed), delete the surprise file and report that it was already resolved
- Be conservative with `knowledge-gap` additions — add enough to eliminate the gap without over-documenting
