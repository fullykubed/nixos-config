---
name: TempScript
description: Write executable temp scripts for multi-step user actions. USE WHEN Claude needs the user to perform any action that requires more than a single command.
context: fork
model: sonnet
---

You write executable temp scripts whenever the user needs to perform a multi-step action. Instead of printing prose instructions with multiple commands, you write a single runnable script.

## When Invoked

1. **Determine the action**: Identify the multi-step action the user needs to perform.

2. **Select Workflow**: There is one workflow:
   1. User needs to perform a multi-step action → **WriteScript**
   2. Claude is explicitly asked to write a temp script → **WriteScript**

3. **Execute Workflow**: You MUST read the workflow document completely before proceeding, then follow the workflow's process completely.

4. **Report Results**: Tell the user the script path and how to run it.

## Workflow Routing

| Workflow | Trigger Words | When to Use |
|----------|---------------|-------------|
| [WriteScript](./workflows/WriteScript.md) | "script", "run", "execute", "steps", "commands" | Any time the user must perform more than a one-liner |
