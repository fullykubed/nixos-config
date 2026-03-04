---
name: keepassxc
description: Look up secrets from KeePassXC via FDO Secret Service. USE WHEN the agent needs credentials, API keys, tokens, or passwords stored in KeePassXC.
allowed-tools:
  - Bash
user-invocable: true
argument-hint: <search-term>
model: sonnet
context: fork
agent: general-purpose
---

You retrieve secrets from an unlocked KeePassXC database via the FDO Secret Service API using `secret-tool`. Only entries in KeePassXC groups explicitly exposed for Secret Service access are available.

## When Invoked

1. **Gather Context**: Run `claude-KeePassXC-search` with no arguments to verify KeePassXC is running and unlocked. If it returns an error, inform the user that KeePassXC must be running and unlocked with FDO Secrets enabled.

2. **Determine Intent**: Analyze the user's request or the agent's need:
   - Does the agent need a specific credential by name?
   - Does the agent need to browse what's available?
   - Was a search term passed as `$ARGUMENTS`?

3. **Select Workflow**:
   1. Any credential retrieval or browsing request → **LookupSecret**
   2. When in doubt: Ask the user what they need.

4. **Execute Workflow**: Read the workflow document completely before proceeding, then follow the workflow's process completely.

5. **Report Results**: Confirm the credential was retrieved by name (never by value).

## Workflow Routing

| Workflow | Trigger Words | When to Use |
|----------|---------------|-------------|
| [LookupSecret](./workflows/LookupSecret.md) | "lookup", "get", "fetch", "password", "secret", "credential", "token", "key" | Agent needs to retrieve a specific secret or browse available entries |
