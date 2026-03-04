# FileIssue Workflow

This workflow guides you through filing a GitHub issue using `gh issue create`, ensuring compliance with the repository's contributing policy and issue templates.

## Overview

```
┌─────────────────────────────────┐
│  1. Gather Context              │
│  claude-GitHub-repo-info        │
└──────────────┬──────────────────┘
               │
       ┌───────┴───────┐
       │ in_git_repo?  │
       └───┬───────┬───┘
       yes │       │ no
           │       │
           │   ┌───┴──────────────┐
           │   │ Ask user for     │
           │   │ OWNER/REPO       │
           │   └───┬──────────────┘
           │       │
       ┌───┴───────┴──────────────┐
       │  2. Check Contributing   │
       │     & AI Policy          │
       └──────────────┬──────────────┐
                      │              │
              ┌───────┴───────┐      │
              │ AI forbidden? │      │
              └───┬───────┬───┘      │
              yes │       │ no       │
                  │       │          │
    ┌─────────────┴──┐    │   ┌──────┴──────────┐
    │ STOP — tell    │    │   │ Note disclosure  │
    │ user, abort    │    │   │ & filing reqs    │
    └────────────────┘    │   └──────┬──────────┘
                          │          │
                  ┌───────┴──────────┴────────┐
                  │  3. Fetch Issue Template   │
                  └──────────────┬─────────────┘
                                 │
                  ┌──────────────┴─────────────┐
                  │ Repo has templates?         │
                  └──┬──────────┬───────────┬──┘
              multiple│    single│      none │
                      │         │           │
         ┌────────────┴──┐  ┌───┴────┐  ┌───┴──────────────┐
         │ Ask user which│  │ Use it │  │ Select default by │
         │ template      │  │        │  │ issue type:       │
         └────────┬──────┘  └───┬────┘  │ bug → bug-report  │
                  │             │        │ feat → feat-req   │
                  │             │        │ other → ask user  │
                  │             │        └───┬──────────────┘
                  └──────┬──────┴────────────┘
                         │
              ┌──────────┴────────────────┐
              │  4. Draft the Issue        │
              │  Fill template sections    │
              │  Gist long code blocks     │
              │  Save to $ISSUE_DRAFT      │
              └──────────┬────────────────┘
                         │
              ┌──────────┴────────────────┐
              │  5. Search Existing Issues │
              │  gh issue list --search    │
              └──────────┬────────────────┘
                         │
              ┌──────────┴──────────┐
              │ Categorize results  │
              └──┬────────┬─────┬──┘
       materially│  related│     │ none
         similar │        │     │
                 │        │     │
    ┌────────────┴────┐   │     │
    │ Ask user:       │   │     │
    │ open → comment? │   │     │
    │ closed → reopen?│   │     │
    └────────┬────────┘   │     │
             │    ┌───────┴──┐  │
             │    │ Update   │  │
             │    │ draft w/ │  │
             │    │ related  │  │
             │    │ issues   │  │
             │    └───┬──────┘  │
             └────┬───┴─────────┘
                  │
         ┌────────┴───────┐
         │ Bug report?    │
         └──┬──────────┬──┘
         yes│          │ no
            │          │
  ┌─────────┴──────────────┐
  │  6. Root Cause Analysis │──────┐
  │  Spawn github-rca agent│      │
  └─────────┬──────────────┘      │
            │                     │
   ┌────────┴─────────┐          │
   │ Confidence?      │          │
   └──┬────────────┬──┘          │
 high/│            │ low         │
 med  │            │             │
      │    ┌───────┴──────┐      │
      │    │ Discard      │      │
      │    │ results      │      │
      │    └───────┬──────┘      │
┌─────┴──────────┐ │             │
│ Update draft:  │ │             │
│ root cause,    │ │             │
│ evidence,      │ │             │
│ suggested fixes│ │             │
└─────┬──────────┘ │             │
      └──────┬─────┴─────────────┘
             │
  ┌──────────┴────────────────┐
  │  7. Strip PII             │
  │  Read & redact $ISSUE_DRAFT│
  └──────────┬────────────────┘
             │
  ┌──────────┴────────────────┐
  │  8. Present Draft         │
  │  Show title & body        │
  └──────────┬────────────────┘
             │
    ┌────────┴────────┐
    │ User response   │
    └──┬──────┬────┬──┘
  approve  changes reject
       │      │      │
       │  ┌───┴────┐ │
       │  │ Apply, │ │
       │  │ re-PII,├─┘──→ back to Step 4
       │  │ re-show│
       │  └───┬────┘
       │      │
       │◄─────┘
       │
  ┌────┴──────────────────────┐
  │  9. File the Issue        │
  │  claude-GitHub-file-issue │
  │  $ISSUE_DRAFT             │
  └──────────┬────────────────┘
             │
  ┌──────────┴────────────────┐
  │  10. Report Result        │
  │  Show URL or error        │
  └───────────────────────────┘
```

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Gather Context

Run `claude-GitHub-repo-info` to determine the current repository context.

| Situation | Action |
|-----------|--------|
| `in_git_repo` is `true` | Use `owner` and `repo` from the output; proceed to Step 2 |
| `in_git_repo` is `false` | Tell the user: "You are not in a git repository. Please provide the target repository in OWNER/REPO format (e.g. `octocat/hello-world`)." Then use their response as the target repo. |

### 2. Check Contributing Policy and AI Policy

Before drafting anything, check whether the repository permits AI-generated issue reports. There is no single standard for where projects publish AI policies, so check multiple locations.

**Check for a standalone AI policy file** (check in order, use the first one found):

1. `AI_POLICY.md`
2. `.github/AI_POLICY.md`

```bash
gh api repos/OWNER/REPO/contents/AI_POLICY.md --jq '.content' 2>/dev/null | base64 -d
gh api repos/OWNER/REPO/contents/.github/AI_POLICY.md --jq '.content' 2>/dev/null | base64 -d
```

**Check for contributing guidelines** (check in order, use the first one found):

1. `.github/CONTRIBUTING.md`
2. `CONTRIBUTING.md`
3. `docs/CONTRIBUTING.md`

```bash
gh api repos/OWNER/REPO/contents/.github/CONTRIBUTING.md --jq '.content' 2>/dev/null | base64 -d
```

If none of the above files exist, that is fine — proceed to Step 3.

**Evaluate all found documents for AI policy:**

Read every policy document found (both the AI policy file and the contributing file, if they exist) and evaluate:

| Finding | Action |
|---------|--------|
| Any document explicitly **forbids** AI-generated issues (e.g., "no AI-generated issues", "do not use LLMs to file issues", "AI-generated reports will be closed") | **STOP.** Tell the user: "This repository's contributing/AI policy forbids AI-generated issue reports. This workflow cannot proceed." Do NOT continue. |
| Any document requires **disclosure** of AI involvement (e.g., `Assisted-by:` trailers, AI attribution checkbox) | Note the disclosure requirements — incorporate them into the issue body in Step 4 |
| Any document has specific issue filing requirements (e.g., required sections, formatting rules, labels to use) | Note these requirements — they will override the template in Step 3 |
| No mention of AI policy in any document | Proceed to Step 3 |

### 3. Fetch Issue Template

Check the repository for issue templates and use one if available.

**Check for templates (in order):**

1. `.github/ISSUE_TEMPLATE/` directory — list files with `gh api repos/OWNER/REPO/contents/.github/ISSUE_TEMPLATE`
2. `.github/ISSUE_TEMPLATE.md` — single template file

```bash
# List template directory contents
gh api repos/OWNER/REPO/contents/.github/ISSUE_TEMPLATE --jq '.[].name' 2>/dev/null

# Or fetch a single template
gh api repos/OWNER/REPO/contents/.github/ISSUE_TEMPLATE.md --jq '.content' 2>/dev/null | base64 -d
```

| Finding | Action |
|---------|--------|
| Template directory exists with multiple templates | Present the template names to the user and ask which one to use, then fetch and parse its structure |
| Single template file exists | Fetch and use its structure |
| No templates found | Use a default template based on issue type (see below) |

**Default template selection** (when the repo has no templates):

| Issue type | Template |
|------------|----------|
| Bug report | `./reference/bug-report-template.md` |
| Feature request | `./reference/feature-request-template.md` |
| Other (question, docs, etc.) | Ask the user which template to use: bug report or feature request |

### 4. Draft the Issue

Using the conversation context, the user's request, and any information available in the current session, automatically generate a complete draft of the issue:

- **Title**: Write a concise, descriptive title based on what the user described
- **Body**: Fill in every section of the template (whether from the repo or the default) using information from:
  - The user's description of the problem or request
  - Code, logs, or error messages discussed in the conversation
  - Environment details available from the system (OS, tool versions, etc.)
  - Any other relevant context from the current session

If the contributing policy from Step 2 specified additional requirements (e.g., formatting rules, specific sections, AI disclosure), incorporate those into the draft.

All fenced code blocks in the body **must** include a language identifier (e.g., `` ```python ``, `` ```bash ``, `` ```nix ``). Use `text` for plain log output or error messages with no specific language.

For any template section where there is genuinely no information available, write a reasonable placeholder (e.g., "N/A" or "Not yet determined") rather than leaving it blank.

**Externalize long code blocks to gists:**

After drafting, scan the body for fenced code blocks (`` ``` ``), log excerpts, and error output that exceed **10 lines**. For each one:

1. Write the content to a temp file with a descriptive name (e.g., `/tmp/traceback.log`, `/tmp/config-snippet.nix`)
2. Run the CreateGist workflow (`./workflows/CreateGist.md`) on that file — the gist **must be public** since it will be linked from an issue
3. Replace the code block in the draft body with a link to the gist:
   ```
   [Full error output](<gist-url>)
   ```

Code blocks of 10 lines or fewer remain inline in the issue body.

**Save the draft to a temp file:**

```bash
ISSUE_DRAFT=$(mktemp /tmp/gh-issue-XXXXXX.md)
```

Write the title on the first line and the body starting on the third line:

```
<title>

<body>
```

This file will be read and updated by subsequent steps.

### 5. Search for Existing Issues

Before investigating further, check whether a materially similar issue already exists in the repository.

Extract 2–4 key terms from the drafted title and body in `$ISSUE_DRAFT` (e.g., error names, affected component, core symptom). Search using those keywords:

```bash
gh issue list --repo OWNER/REPO --state all --search "KEYWORDS" --limit 20 --json number,title,state,url
```

If the first search returns no relevant results, try a second search with alternate terms (e.g., synonyms, error codes, or the function/module name).

**Categorize each returned issue** by comparing it against the draft:

| Category | Criteria |
|----------|----------|
| **Materially similar** | Describes the same symptom, error, or feature request — even if worded differently |
| **Related** | Involves the same component, area, or a connected issue, but is not the same problem |
| **Unrelated** | Returned by the keyword search but not relevant to this issue |

Discard unrelated issues. Then act based on the highest-priority category found:

| Finding | Action |
|---------|--------|
| A **materially similar** open issue exists | Tell the user: "An existing open issue may cover this: #NUMBER — TITLE (URL). Would you like to continue filing a new issue, or add a comment to the existing one instead?" Wait for the user's response before proceeding. |
| A **materially similar** closed issue exists | Tell the user: "A similar issue was previously filed and closed: #NUMBER — TITLE (URL). Would you like to continue filing a new issue, or reopen the existing one?" Wait for the user's response before proceeding. |
| Only **related** issues found | Update `$ISSUE_DRAFT` with the related issues (see below) and proceed to Step 6. |
| No similar or related issues found | Proceed to Step 6. |

**Adding related issues to the draft:**

Read `$ISSUE_DRAFT` and find the "Related Issues" section (or "Related", "See Also", or similar). If the template has no such section, add a "## Related Issues" section before "## Additional Context" (or at the end of the body if neither exists).

For each related issue, add a bullet with the issue number, title, and a brief note on how it relates:

```markdown
## Related Issues

- #42 — Login timeout on slow connections (same auth component, different symptom)
- #87 — Session store migration plan (related infrastructure change)
```

Write the updated draft back to `$ISSUE_DRAFT`.

### 6. Root Cause Analysis

This step only applies to **bug reports**. If the issue is a feature request, question, documentation improvement, or any other non-bug issue type, skip to Step 7.

Check whether the template contains a section titled "Additional Context", "Root Cause Analysis", "Root Cause", "Analysis", "Suggested Fix", "Suggestions", or similar.

| Condition | Action |
|-----------|--------|
| Issue is not a bug report | Skip to Step 7 |
| Template has such a section | Perform a root cause analysis and update the draft |
| Template does not have such a section | Skip to Step 7 |

**Performing the analysis:**

Create a temp file for the agent to write its findings to:

```bash
RCA_OUTPUT=$(mktemp /tmp/gh-rca-XXXXXX.json)
```

Use the Task tool to spawn a `github-rca` subagent. The agent writes its findings to the output file (validated by a PostToolUse hook).

| Parameter | Value |
|-----------|-------|
| `subagent_type` | `"github-rca"` |
| `description` | Brief label, e.g. `"Investigate root cause of <symptom>"` |
| `prompt` | Must include the three required inputs (see below) |

**Prompt must include:**
- `Draft path`: The `$ISSUE_DRAFT` temp file path so the agent can read the issue details
- `Repo path`: Absolute path to the repository being investigated
- `Output path`: The `$RCA_OUTPUT` temp file path where the agent must write its JSON findings

**Example Task invocation:**

```
Task(
  subagent_type: "github-rca",
  description: "Investigate login redirect failure",
  prompt: "Draft path: /tmp/gh-issue-a1b2c3.md\n\nRepo path: /home/user/repos/my-app\n\nOutput path: /tmp/gh-rca-x9y8z7.json"
)
```

**Update the draft with findings:**

After the agent returns, read `$RCA_OUTPUT` and check the `confidence` field.

| Confidence | Action |
|------------|--------|
| `high` or `medium` | Update the draft with the findings (see below) |
| `low` | Discard the results — do not modify the draft |

If confidence is `high` or `medium`, read the draft from `$ISSUE_DRAFT` and replace the placeholder content in the root cause / analysis / additional context section with the agent's findings. Write the following into that section:

- `root_cause` — as the primary explanation
- `evidence` — as a bullet list of supporting evidence
- `contributing_factors` — as a bullet list (if any)

If the template has a suggested fix, suggestions, analysis, or further information section, also populate it with `suggested_fixes`. For each fix, include its description, the list of changes (location and what to change), trade-offs, and confidence level.

Write the updated draft back to `$ISSUE_DRAFT`.

### 7. Strip Personally Identifiable Information

Read the PII stripping guide: `@./reference/pii-stripping.md`

Read the draft from `$ISSUE_DRAFT`. Follow the "For issue bodies and text content" process from that guide. Scan the drafted title and body for PII, redact any findings, and write the result back to `$ISSUE_DRAFT`.

### 8. Present Draft for Review

Read the draft from `$ISSUE_DRAFT` (title is the first line, body starts on the third line). Present the complete drafted issue to the user for review before filing. The user must approve or request changes before proceeding.

Display the draft clearly so the user can evaluate it:

```
**Title:** <drafted title>

**Body:**
<drafted body with all template sections filled in>
```

| User Response | Action |
|---------------|--------|
| Approves the draft | Proceed to Step 9 |
| Requests changes | Apply the changes, re-run PII stripping (Step 7), and present the updated draft again |
| Rejects the draft entirely | Ask what they want changed and redraft from Step 4 |

Do NOT proceed to Step 9 without explicit user approval.

### 9. File the Issue

Run `claude-GitHub-file-issue` with the draft file to create the issue.

```bash
claude-GitHub-file-issue "$ISSUE_DRAFT"
```

If not in a git repo, append `--repo OWNER/REPO`:

```bash
claude-GitHub-file-issue "$ISSUE_DRAFT" --repo OWNER/REPO
```

The script reads the title and body from the draft file and calls `gh issue create`. It outputs the created issue URL on success or an error message on failure.

### 10. Report the Result

After the command runs, report the outcome to the user.

| Outcome | Action |
|---------|--------|
| Command succeeds | Show the user the created issue URL returned by `gh` |
| Command fails | Show the error message from `gh` and suggest corrective action |

## Guidelines

- **Always check contributing policy first** — if the repo forbids AI-generated issues, stop immediately
- **Draft everything automatically** — fill in the title and every template section from available context before showing the user; never ask the user to provide information section by section
- **Always get user approval** — never file an issue without the user explicitly approving the draft
- **Always strip PII** — scan the drafted issue for personally identifiable information before presenting to the user
- **Always use a template** — either the repo's own template or the default; never file a free-form issue with no structure
- **Respect repo-specific requirements** — if the contributing guide specifies formatting, sections, or processes, follow them exactly
- **Quote all string values** in the `gh` command to handle spaces and special characters correctly
- **Do not set assignees, labels, or milestones** — let the repository maintainers triage the issue
