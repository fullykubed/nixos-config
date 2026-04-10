# FullBuild Workflow

Build the complete NixOS system derivation without switching to it. This is the most thorough test — if it passes, the configuration is ready to deploy. Takes minutes to hours depending on what needs to be compiled.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Run Full Build

```bash
nt-build [hostname]
```

Hostname defaults to the current machine. Remote builders will be used automatically if configured.

The script writes all build output to a temp log file and prints the path to stderr. Record this path. If the build appears stalled, inspect recent log lines:

```bash
tail -n 50 <log-path>
```

### 2. Report Results

- **Build succeeded**: Report success. The system is ready to deploy with `un`.
- **Build failed**: Read the log to show the error:
  ```bash
  tail -n 150 <log-path>
  ```
  Classify the failure:

  | Error type | Suggestion |
  |------------|-----------|
  | Eval error | Run **EvalCheck** (`nt-eval`) to isolate the issue |
  | Single package failure | Run **BuildPackage** (`nt-pkg`) on the failing package to iterate faster |
  | Hash mismatch | Source hash needs updating — check `modules/patches/` |
  | Compilation error | Check if the package needs a mold exclusion or a patch fix |

  If the user wants automatic fix-and-retry, suggest using the **NixOSBuild** skill instead, which has a build-fix loop.

## Guidelines

- This is the heaviest test — only run it when lighter tests (EvalCheck, DryBuild) have already passed or when the user explicitly asks for a full build.
- For iterating on build failures, use **BuildPackage** (`nt-pkg`) on the specific failing package — it's much faster than rebuilding the entire system each time.
- The full build uses the same derivation that `un` (the deploy command) builds, so if this passes, deployment will succeed.
