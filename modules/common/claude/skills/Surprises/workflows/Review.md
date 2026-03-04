# Review Workflow

Review all open documentation surprises one by one. Each surprise is presented to the user for a decision: ignore it (skip for now), reject it (false positive — delete the file), or fix it in place.

## Prerequisites

- At least one surprise file must exist in `.claude/surprises/` in the default branch worktree
- If no surprises exist, report "No surprises to review" and exit

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. List Open Surprises

Run `claude-Surprises-list` to get all open surprises:

```bash
claude-Surprises-list
```

If the result is `[]`, report that there are no open surprises and stop.

Report to the user:

```
Found <N> surprise(s) to review
```

### 2. Review Each Surprise

For each surprise in the list (in date order, oldest first), present it for review:

1. **Read the surprise** — run `claude-Surprises-get <slug>` to get the full content.

2. **Show the surprise** — display it clearly:
   ```
   ─────────────────────────────────────────────────────────────────────────────
   Surprise <i>/<N>: <title>
   Category: <category>
   Date: <date>
   Sources: <sources list>
   ─────────────────────────────────────────────────────────────────────────────

   Expected: <expected>
   Found:    <found>

   Recommended Resolution: <recommended resolution>
   ```

3. **Ask the user** using AskUserQuestion:
   - Question: `Surprise <i>/<N>: <title> — <brief summary of the discrepancy>?`
   - Options:
     - **Ignore** — Skip this surprise for now (leave the file in place)
     - **Reject** — Dismiss as a false positive (delete the file without making changes)
     - **Fix** — Apply the recommended resolution

4. **Handle response:**
   - **Ignore**: Skip this surprise entirely. Continue to next surprise.
   - **Reject**: Mark this surprise for deletion. Continue to next surprise.
   - **Fix**: Follow the fix procedure (Step 3 below) before continuing to the next surprise.

### 3. Fix Procedure

When the user chooses to fix a surprise, apply the resolution inline:

1. **Read source files** — read all files listed in the surprise's `sources` frontmatter
2. **Read additional context** — read any related files referenced by the sources
3. **Apply the fix** based on the category:

   | Category | Fix Approach |
   |----------|-------------|
   | `stale-reference` | Update or remove the stale reference; verify the correct path/name |
   | `incorrect-instruction` | Correct the documented command, step, or instruction to match actual behavior |
   | `knowledge-gap` | Add missing documentation to the appropriate file(s) |
   | `contradiction` | Identify which doc is correct and update the incorrect one |
   | `failed-action` | Document in the relevant file what should NOT be done and why |

4. **Verify the fix** — re-read the modified file(s) to confirm accuracy
5. **Mark as fixed** — record this surprise as fixed for the summary

### 4. Delete Surprise Files

After all surprises have been reviewed, delete the surprise files for rejected and fixed surprises. Ignored surprises are left in place.

```bash
# Resolve the default branch worktree path
MAIN_WORKTREE=$(git-default-worktree-path)

# Delete each rejected or fixed surprise file (NOT ignored ones)
rm "$MAIN_WORKTREE/.claude/surprises/<slug>.md"
```

### 5. Report Summary

```
=============================================================================
SURPRISE REVIEW COMPLETE
=============================================================================

Reviewed: <N> surprise(s)
  Fixed:    <F>
  Rejected: <R>
  Ignored:  <I>

Fixed:
  - <title_1>: <brief description of what was changed>
  - <title_2>: <brief description of what was changed>

Rejected:
  - <title_3>
  - <title_4>

Ignored:
  - <title_5>
  - <title_6>

Remaining: <X> surprise(s) still open
=============================================================================
```

## Guidelines

- Present surprises one at a time — never batch all surprises into a single question
- Show enough context for the user to make an informed decision on each surprise
- When fixing, prefer minimal targeted edits that address exactly the documented discrepancy
- Do not "improve" documentation beyond what the surprise requires — stay focused on the specific issue
- If investigation during a fix reveals the surprise is no longer valid, inform the user and treat it as a reject
- If the recommended resolution is unclear or would require significant refactoring, mention this when presenting the surprise so the user can make an informed choice
