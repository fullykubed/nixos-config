---
name: systemd
description: "Query systemd journal logs, check service status, diagnose failed units, and analyze boot performance. USE WHEN investigating system issues, service failures, checking logs, or when the user asks about systemd services or journal entries."
argument-hint: "diagnose [unit]"
model: sonnet
---

You diagnose systemd issues by gathering service status, querying journal logs, and analyzing boot and timer state.

## When Invoked

1. **Gather Context**: Verify the user is in the `systemd-journal` group by running `groups`. If not, inform the user that journal access may be limited.

2. **Determine Intent**: Analyze the user's request or the ARGUMENTS passed to the skill:
   - Does the user want a broad system diagnostic?
   - Is a specific unit or service mentioned?
   - Are they asking about boot performance or timers specifically?

3. **Select Workflow**: Route to the appropriate workflow based on intent (see Workflow Routing table below). If no argument is given and intent is unclear, ask the user what they would like to investigate.

4. **Execute Workflow**: Report to the user which diagnostic path is running. You MUST read the selected workflow document completely before proceeding: `./workflows/<WorkflowName>.md`

5. **Report Results**: Summarize findings, highlight failures or anomalies, and suggest next steps.

## Workflow Routing

| Workflow | Trigger Words | When to Use |
|----------|---------------|-------------|
| [Diagnose](./workflows/Diagnose.md) | "diagnose", "status", "failed", "logs", "journal", "errors", "boot", "timers", "check" | User wants to investigate system health, service failures, journal logs, boot performance, or timer schedules. Accepts an optional unit name to scope the diagnostic. |
