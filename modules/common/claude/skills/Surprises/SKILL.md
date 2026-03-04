---
name: Surprises
description: Review and fix documentation surprises discovered by the surprise hook. USE WHEN the user wants to fix documentation issues, review surprises, or address items in .claude/surprises/.
---

You manage documentation surprises through their complete lifecycle. Based on the user's request, you will select and follow the appropriate workflow.

## When Invoked

1. **Gather Context**: Run `claude-Surprises-list` to check for open surprises:
   - If no surprises exist, report that there is nothing to fix
   - If surprises exist, present the list to the user

2. **Determine Intent**: Analyze the user's request to identify:
   - Did the user pass a specific surprise slug as an argument?
   - Do they want to fix a specific surprise or work through all open surprises?
   - Look for trigger words from the Workflow Routing table

3. **Select Workflow**: Select the appropriate workflow based on the user's intent and trigger words:
   1. Does the user want to review, triage, or go through surprises? → **Review**
   2. Does the user want to fix, resolve, or address a specific surprise? → **Fix**
   3. When in doubt: Ask the user which workflow they want.

4. **Execute Workflow**: Report to the user "Running <workflow> workflow using the Surprises skill..." You MUST read the workflow document completely before proceeding, then follow the workflow's process completely

5. **Report Results**: Summarize what was fixed and how many surprises remain

## Workflow Routing

| Workflow | Trigger Words | When to Use |
|----------|---------------|-------------|
| [Review](./workflows/Review.md) | "review", "triage", "go through", "check" | User wants to review all open surprises and decide on each one |
| [Fix](./workflows/Fix.md) | "fix", "resolve", "address" | User wants to fix a specific documentation surprise |
