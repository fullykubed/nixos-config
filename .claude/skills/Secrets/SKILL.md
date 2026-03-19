---
name: Secrets
description: Create and update agenix-encrypted secrets non-interactively using YubiKey recipients. USE WHEN the user wants to create a new secret, update an existing secret, or store a sensitive value in the secrets directory.
argument-hint: "[secret-name] [value-or-source]"
allowed-tools: Read, Grep, Glob, Bash
---

You create and update age-encrypted secrets for this NixOS configuration using the `create-secret` devshell script and YubiKey master identities.

## When Invoked

1. **Gather Context**: Determine what the user needs:
   - What should the secret be named?
   - Where does the secret value come from? (user-provided, generated, fetched from a service)
   - Does a secret with this name already exist in `secrets/`?
   - Which module will consume this secret?

2. **Determine Intent**: Analyze the user's request:
   - Are they creating a brand new secret? → **CreateSecret**
   - Are they updating an existing secret's value? → **CreateSecret** (with `--force`)
   - Look for trigger words from the Workflow Routing table

3. **Select Workflow**: This skill has a single workflow:
   1. Creating or updating a secret → **CreateSecret**

4. **Execute Workflow**: Report to the user "Running CreateSecret using the Secrets skill..." You MUST read the workflow document completely before proceeding, then follow the workflow's process completely.

5. **Report Results**: Summarize what was created and list remaining steps (module reference, git add, deploy).

## Workflow Routing

| Workflow | Trigger Words | When to Use |
|----------|---------------|-------------|
| [CreateSecret](./workflows/CreateSecret.md) | "create secret", "add secret", "new secret", "store secret", "encrypt", "update secret", "change secret" | User wants to create or update an age-encrypted secret |

## Quick Reference

### Secret storage layout

```
secrets/
├── <name>.age           # Age-encrypted secret (encrypted to YubiKey recipients)
├── machines/<host>/     # Per-machine secrets (host keys, syncthing)
└── rekeyed/<host>/      # Per-host rekeyed copies (auto-generated)
```

### Module reference pattern

```nix
age.secrets.<name> = {
  rekeyFile = ../../../secrets/<name>.age;
};
# Decrypted at runtime: config.age.secrets.<name>.path → /run/agenix/<name>
```
