---
name: NixOSTest
description: Test NixOS configuration changes using the feedback ladder — from instant syntax checks to full system builds. USE WHEN the user wants to verify, test, or check NixOS changes before deploying.
argument-hint: "[test-level] [file-or-package]"
allowed-tools: Read, Grep, Glob, Bash
---

You run NixOS verification tests against configuration changes. **Always prefer the fastest workflow that can catch the error.** Run workflows in sequence from fastest to slowest, stopping at the first failure. Never jump to a slow workflow when a fast one hasn't been run yet.

## Feedback Ladder

Workflows are ordered from fastest to slowest. Always start as high on this ladder as possible and work downward only when the previous level passes:

| Level | Workflow | Time | What it catches |
|-------|----------|------|-----------------|
| 1 | **SyntaxCheck** | ~instant | Missing semicolons, unmatched brackets, parse errors |
| 2 | **EvalCheck** | ~seconds | Missing attributes, type errors, assertion failures, infinite recursion |
| 3 | **DryBuild** | seconds–minutes | Everything in eval + hash mismatches in source fetches |
| 4 | **BuildPackage** | seconds–hours | Patch failures, compilation errors for a single package |
| 5 | **BuildOption** | variable | Build failures in a specific subsystem (kernel, initrd, etc) |
| 6 | **FullBuild** | minutes–hours | Everything — full system compilation |
| 7 | **RunChecks** | ~minutes | Formatting, lint, secret leaks (independent of the ladder) |

**RunChecks** is independent — it can run at any point alongside the ladder.

## When Invoked

1. **Detect Hostname**: The `nt-*` scripts auto-detect the hostname. If you need to verify or list available configurations, run:

   ```bash
   nt-hosts
   ```

   This lists all `nixosConfigurations` and marks the current host. If the hostname doesn't match any known config, ask the user which configuration to test against.

2. **Detect Repo Root**: Find the repo root with `git rev-parse --show-toplevel`. All nix commands MUST be run from this directory.

3. **Determine Intent**: Analyze the user's request to identify:
   - What level of testing they need (syntax, eval, build, etc.)
   - Whether they're targeting a specific file, package, or the whole system
   - Look for trigger words from the Workflow Routing table

4. **Select Workflow**: If the user specified a test level, use that workflow directly. Otherwise, **always pick the cheapest workflow that covers the change**:

   | Situation | Start at | Why |
   |-----------|----------|-----|
   | User edited a `.nix` file and wants a quick check | **SyntaxCheck** (~instant) | Catches syntax errors in milliseconds |
   | User wants to verify the config evaluates | **EvalCheck** (~seconds) | Catches most config errors without building |
   | User wants to see what would be built | **DryBuild** (seconds–min) | Resolves all derivations without compiling |
   | User is working on a specific package (patch, overlay) | **BuildPackage** (seconds–hours) | Only builds the one package that changed |
   | User wants to verify a specific config option | **BuildOption** (variable) | Isolates one subsystem |
   | User wants to confirm the full system builds | **FullBuild** (minutes–hours) | Last resort — only after lighter tests pass |
   | User wants to run linters and flake checks | **RunChecks** (~minutes) | Independent of the build ladder |
   | User says "test" with no other context | **EvalCheck** (~seconds) | Best cost/coverage ratio as a starting point |

   **Key rule**: If you pick a workflow and it passes, suggest the next level down. If it fails, stop and report — there's no point running a heavier test when a lighter one already found the problem.

5. **Execute Workflow**: Report to the user "Running <workflow-name> using the NixOSTest skill..." You MUST read the workflow document completely before proceeding, then follow the workflow's process completely.

6. **Report Results**: Summarize pass/fail with the time the workflow took. On success, suggest the next level of the feedback ladder. On failure, stop and help fix the error — do NOT proceed to heavier workflows.

## Workflow Routing

| Workflow | Time | Trigger Words | When to Use |
|----------|------|---------------|-------------|
| [SyntaxCheck](./workflows/SyntaxCheck.md) | ~instant | "syntax", "parse", "quick check" | Instant syntax validation of .nix files |
| [EvalCheck](./workflows/EvalCheck.md) | ~seconds | "eval", "evaluate", "check config" | Verify the full config evaluates without errors |
| [DryBuild](./workflows/DryBuild.md) | seconds–min | "dry run", "dry-run", "what would build" | See what would be built without building |
| [BuildPackage](./workflows/BuildPackage.md) | seconds–hours | "build package", "test package", "check package" | Build a single package to verify patches/overlays |
| [BuildOption](./workflows/BuildOption.md) | variable | "build option", "test option", "check option", "kernel", "etc" | Build a specific config option derivation |
| [FullBuild](./workflows/FullBuild.md) | minutes–hours | "full build", "build system", "build all", "build everything" | Build the complete system without switching |
| [RunChecks](./workflows/RunChecks.md) | ~minutes | "check", "lint", "flake check", "pre-commit" | Run nix flake check and linter suite |
