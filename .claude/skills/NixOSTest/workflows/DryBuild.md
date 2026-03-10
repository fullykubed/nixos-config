# DryBuild Workflow

Check what would be built without actually building anything. This evaluates the full configuration and resolves all derivations, showing which store paths are missing and would need to be built or fetched. Takes seconds to minutes.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Run Dry Build

```bash
nt-dry [hostname]
```

Hostname defaults to the current machine.

### 2. Interpret Results

The output shows two categories:

- **"these derivations will be built:"** — Packages that need to be compiled from source.
- **"these paths will be fetched:"** — Packages that can be downloaded from a binary cache.

| Output | Meaning |
|--------|---------|
| No output (silent success) | Everything is already in the store — nothing to build |
| List of derivations to build | These packages need compilation |
| List of paths to fetch | These can be downloaded from the cache |
| Error output | Evaluation failed — suggest running **EvalCheck** first |

### 3. Report Results

- **Success (nothing to build)**: The system is already up to date. Report this.
- **Success (builds needed)**: Summarize what would be built. If only a few packages, list them. If many, give a count and highlight notable ones (kernel, large packages).
- **Failure**: Show the error and suggest running **EvalCheck** to diagnose.

## Guidelines

- Dry build catches everything eval check catches, plus it resolves fixed-output derivations (fetchers) — so it can detect hash mismatches in source fetches.
- A large number of derivations to build may indicate a stdenv change or mass rebuild — flag this to the user.
- This is the last "free" check before actual compilation starts.
