---
name: NixOSBuild
description: Build the NixOS system derivation, analyze build errors, and automatically apply fixes in a loop until the build succeeds. USE WHEN the user wants to build and fix errors automatically, or mentions deploying, building, or fixing build errors.
argument-hint: <hostname> <worktree>
---

You automatically build the NixOS system and fix build errors in an iterative loop until the build succeeds.

## When Invoked

1. **Parse Arguments**: Extract hostname and worktree from ARGUMENTS. Ask for any missing arguments.
   - `<hostname>` — NixOS configuration to build. Valid: `fullykubed-tower`, `fullykubed-mini-pc`
   - `<worktree>` — Worktree directory name to build from (e.g., `main`, `my-feature-branch`)

2. **Gather Context**: Verify the worktree directory exists at `@home@/repos/nixos-config/<worktree>/`. If not, list available worktrees and ask the user:
   ```bash
   git -C @home@/repos/nixos-config/main worktree list
   ```

3. **Select Workflow**: Route to the appropriate workflow based on the user's intent (see Workflow Routing table below).

4. **Execute Workflow**: Report to the user which workflow is running and for which hostname/worktree. You MUST read the selected workflow document completely before proceeding. Since this is a system-level skill, read it relative to this SKILL.md file: `./workflows/<WorkflowName>.md`

5. **Report Results**: The workflow handles its own reporting.

## Workflow Routing

| Workflow | Trigger Words | When to Use |
|----------|---------------|-------------|
| [Build](./workflows/Build.md) | "build", "deploy", "fix build", "auto fix", "build errors", "nix build", "rebuild", "fix errors" | User wants to build the NixOS system and automatically fix any build errors that occur |
| [ReviewAutofixes](./workflows/ReviewAutofixes.md) | "review", "approve", "review fixes", "approve fixes", "review autofixes", "check fixes" | User wants to review accumulated autofixes — does not block the Build workflow; this is an on-demand review of previously applied fixes |

## Reference

- [CLI Tools](./reference/cli-tools.md)
