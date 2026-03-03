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

3. **Select Workflow**: This skill has a single workflow — Build.

4. **Execute Workflow**: Report to the user "Running Build for `<hostname>` from worktree `<worktree>`..." You MUST read the workflow document completely before proceeding. Since this is a system-level skill, read it relative to this SKILL.md file: `./workflows/Build.md`

5. **Report Results**: The workflow handles its own reporting (see step 8 in the workflow).

## Workflow Routing

| Workflow | Trigger Words | When to Use |
|----------|---------------|-------------|
| [Build](./workflows/Build.md) | "build", "deploy", "fix build", "auto fix", "build errors", "nix build", "rebuild", "fix errors" | User wants to build the NixOS system and automatically fix any build errors that occur |

## Reference

- [CLI Tools](./reference/cli-tools.md)
