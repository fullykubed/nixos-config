---
name: Dogfood
description: Systematically explore and test a web application to find bugs, UX issues, and other problems. USE WHEN the user wants to quality-test a web app, find issues, dogfood a product, or produce a structured bug report with reproduction evidence.
allowed-tools: Bash(agent-browser:*)
---

You systematically explore a web application and produce a structured report with full reproduction evidence for every finding.

## Setup

Only the Target URL is required. Everything else has sensible defaults -- use them unless the user explicitly provides an override.

| Parameter | Default | Example override |
|-----------|---------|-----------------|
| Target URL | (required) | `http://localhost:3000` |
| Session name | Slugified domain (e.g., `myapp-com`) | `--session my-session` |
| Output directory | `./dogfood-output/` | `Output directory: /tmp/qa` |
| Scope | Full app | `Focus on the settings page` |
| Authentication | None | `Sign in as user@example.com` |

If the user says something like "dogfood localhost:3000", start immediately with defaults. Do not ask clarifying questions unless authentication is mentioned but credentials are missing.

Always use `agent-browser` directly -- never `npx agent-browser`. The direct binary uses the fast Rust client.

## Workflow

```
1. Initialize    Set up session and output directories
2. Authenticate  Sign in if needed
3. Orient        Navigate to starting point, take initial snapshot
4. Explore       Systematically visit pages and test features
5. Document      Screenshot and record each issue as found
6. Wrap up       Update summary counts, close session
```

### 1. Initialize

```bash
mkdir -p {OUTPUT_DIR}/screenshots
agent-browser --session {SESSION} open {TARGET_URL}
agent-browser --session {SESSION} wait --load networkidle
```

### 2. Authenticate

If the app requires login, sign in and capture the authenticated state:

```bash
agent-browser --session {SESSION} snapshot -i
# Fill credentials using refs from snapshot
agent-browser --session {SESSION} fill @e1 "{USERNAME}"
agent-browser --session {SESSION} fill @e2 "{PASSWORD}"
agent-browser --session {SESSION} click @e3
agent-browser --session {SESSION} wait --load networkidle
```

### 3. Orient

Take an initial screenshot and map the app structure:

```bash
agent-browser --session {SESSION} screenshot --annotate {OUTPUT_DIR}/screenshots/initial.png
agent-browser --session {SESSION} snapshot -i
```

Identify: main navigation, key features, entry points for core user flows.

### 4. Explore

Work through the app systematically. For each page or feature:

```bash
agent-browser --session {SESSION} snapshot -i
agent-browser --session {SESSION} screenshot --annotate {OUTPUT_DIR}/screenshots/{page-name}.png
```

Exploration strategy:
- Follow the main navigation links in order
- On each page: visual scan, click interactive elements, test forms
- Check empty states, error states, and edge cases
- Test core user flows end-to-end

Aim for 5-10 well-documented issues. Breadth beats depth -- cover more of the app rather than exhausting one area.

### 5. Document

Steps 4 and 5 happen together -- explore and document in a single pass. When you find an issue, stop and capture evidence before continuing.

**Every issue must be reproducible.** When you find something wrong, prove it with evidence so someone can replay it.

For each issue:
1. Take an annotated screenshot:
   ```bash
   agent-browser --session {SESSION} screenshot --annotate {OUTPUT_DIR}/screenshots/issue-{N}.png
   ```
2. Note the exact reproduction steps
3. Classify severity and category (see [Issue Taxonomy](./reference/issue-taxonomy.md))
4. Append to the report immediately

Issue format:
```markdown
### ISSUE-{N}: {Brief title}

**Severity**: critical | high | medium | low
**Category**: Functional | UX | Visual | Performance | Accessibility | Content | Console
**URL**: {page url}

**Description**: {What is wrong and why it matters}

**Reproduction Steps**:
1. {Step 1}
2. {Step 2}
3. {Observed result}

**Expected**: {What should happen}

**Evidence**: {screenshots/issue-N.png}
```

### 6. Wrap Up

After exploring:

```bash
agent-browser --session {SESSION} close
```

Re-read the report and update the summary severity counts so they match the actual issues.

Report summary format:
```markdown
## Summary

- **Critical**: {N}
- **High**: {N}
- **Medium**: {N}
- **Low**: {N}
- **Total**: {N}
```

## Guidance

**Use the right snapshot command.**

| Situation | Command |
|-----------|---------|
| Finding interactive elements | `agent-browser snapshot -i` |
| Full page structure | `agent-browser snapshot` |
| Scoped to a section | `agent-browser snapshot -s "#selector"` |
| Modern JS apps with custom elements | `agent-browser snapshot -i -C` |

**Re-snapshot after actions.** Refs become stale after navigation or significant DOM changes.

**Pace exploration.** Move methodically -- don't rush. Each page deserves a visual scan, an interactive check, and a form test if applicable.

**Quality over quantity.** A report with 5 well-documented issues is more useful than 20 vague notes.

## Reference

- [Issue Taxonomy](./reference/issue-taxonomy.md) -- Bug categories, severity levels, and exploration checklist
