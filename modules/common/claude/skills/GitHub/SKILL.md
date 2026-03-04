---
name: GitHub
description: Perform common GitHub operations using the gh CLI. USE WHEN the user wants to file an issue or create a gist.
argument-hint: [action]
---

You perform common GitHub operations using the `gh` CLI based on the user's request.

## When Invoked

1. **Read References**: You MUST read the gh CLI reference completely before proceeding:
   @./reference/gh-commands.md

2. **Gather Context**: Run `claude-GitHub-repo-info` to get current repository context

3. **Determine Intent**: Analyze the user's request to identify:
   - What GitHub operation do they want to perform?
   - Look for trigger words from the Workflow Routing table below

4. **Select Workflow**: Route to the appropriate workflow based on the user's intent:
   1. Does the user want to file a bug, issue, or report? → **FileIssue**
   2. Does the user want to share a snippet, paste, or create a gist? → **CreateGist**
   3. When in doubt: Ask the user which workflow they want to use.

5. **Execute Workflow**: Report to the user "Running <workflow-name> using the GitHub skill..." You MUST read the workflow document completely before proceeding, then follow the workflow's process completely: `./workflows/<WorkflowName>.md`

6. **Report Results**: Summarize what was accomplished and suggest next steps

## Workflow Routing

| Workflow | Trigger Words | When to Use |
|----------|---------------|-------------|
| [FileIssue](./workflows/FileIssue.md) | "file", "issue", "bug", "report" | User wants to create a GitHub issue |
| [CreateGist](./workflows/CreateGist.md) | "gist", "snippet", "share", "paste" | User wants to create a GitHub gist |

## Reference

- [gh Commands](./reference/gh-commands.md)
- [Bug Report Template](./reference/bug-report-template.md)
- [Feature Request Template](./reference/feature-request-template.md)
- [PII Stripping Guide](./reference/pii-stripping.md)
