# Build Workflow

Build-fix-retry loop for NixOS system builds. Builds the system derivation, analyzes errors, applies fixes, and retries until the build succeeds or no further fix strategies remain.

## Repository

The nixos-config repository is at `@home@/repos/nixos-config/`. All operations run from the worktree directory passed as an argument: `@home@/repos/nixos-config/<worktree>/`.

## Reference Documents

Read the relevant reference document when you encounter a specific error type:

| Reference | When to Read |
|-----------|-------------|
| [eval-attr-missing.md](../reference/eval-attr-missing.md) | `EVAL_ATTR_MISSING` — attribute missing, undefined variable |
| [eval-type-error.md](../reference/eval-type-error.md) | `EVAL_TYPE_ERROR` — wrong value type, cannot coerce |
| [eval-infinite-recursion.md](../reference/eval-infinite-recursion.md) | `EVAL_INFINITE_RECURSION` — circular reference in overlays/imports |
| [eval-assertion.md](../reference/eval-assertion.md) | `EVAL_ASSERTION` — assert or option assertion failed |
| [eval-syntax.md](../reference/eval-syntax.md) | `EVAL_SYNTAX` — invalid Nix syntax |
| [test-failures.md](../reference/test-failures.md) | Build-time test failures (doCheck, per-framework disabling) |
| [compilation-errors.md](../reference/compilation-errors.md) | Compiler errors, -Werror, hardening flags, postPatch |
| [missing-dependencies.md](../reference/missing-dependencies.md) | Missing build inputs, transitive dependency overrides |
| [build-flags.md](../reference/build-flags.md) | CMake, Meson, autotools configuration errors |
| [version-upgrades.md](../reference/version-upgrades.md) | Version bumps, inherit from unstable |
| [source-patches.md](../reference/source-patches.md) | Creating and applying .patch files |
| [hash-mismatch.md](../reference/hash-mismatch.md) | Fixed-output derivation hash mismatches |
| [builder-issues.md](../reference/builder-issues.md) | Remote builder, resource, connectivity issues |
| [build-unknown.md](../reference/build-unknown.md) | `BUILD_UNKNOWN` — unrecognized derivation build failure |
| [research.md](../reference/research.md) | Online search strategy for unfamiliar errors (Exa MCP tools) |
| [report-formats.md](../reference/report-formats.md) | Output formats for success/failure reports |

Also consult `patches/default.nix` in the worktree for 50+ real examples of fix patterns.

---

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Initialize

1. **Get hostname and worktree** from skill arguments. Ask for any missing arguments.
2. **Verify hostname** matches a known configuration: `fullykubed-tower`, `fullykubed-mini-pc`. If not, ERROR and exit.
3. **Set worktree path**: `@home@/repos/nixos-config/<worktree>/`
4. **Verify worktree exists**. If not, list available worktrees and ERROR:
   ```bash
   git -C @home@/repos/nixos-config/main worktree list
   ```
5. **Set build command** (all nix build commands run from the worktree directory):
   ```bash
   nix build --no-link --impure @home@/repos/nixos-config/<worktree>#nixosConfigurations.<hostname>.config.system.build.toplevel
   ```
6. **Initialize state directory and attempt history:**
   ```bash
   STATE_DIR=$(claude-NixOSBuild-init-history <worktree>)
   ```
   Store `STATE_DIR` — all subsequent attempt-history commands and build logs use this directory.
7. **Report to user:**
   ```
   Building NixOS configuration for: <hostname>
   Worktree: @home@/repos/nixos-config/<worktree>/
   Build target: nixosConfigurations.<hostname>.config.system.build.toplevel
   State: <STATE_DIR>
   ```

---

### 2. Run Build

1. **Execute build to file (no timeout):**
   ```bash
   nix build --no-link --impure --quiet @home@/repos/nixos-config/<worktree>#nixosConfigurations.<hostname>.config.system.build.toplevel > "$STATE_DIR/build-output.log" 2>&1; echo "EXIT_CODE:$?"
   ```
   - Do NOT set a timeout — builds can run for an extended period
   - Use `--quiet` to suppress progress noise
   - Write all output to `$STATE_DIR/build-output.log` to avoid polluting the context window
   - Use absolute flake path so the command works from any directory

2. **Check result:**
   - **Exit code 0** (success): Go to **step 8**
   - **Exit code ≠ 0** (failure): Proceed to **step 3**

---

### 3. Classify Error and Extract Info

1. **Search for derivation log references** — nix prints lines like `For full logs, run 'nix log /nix/store/<hash>-<name>.drv'`:
   ```bash
   rg -o 'nix log /nix/store/[^ '\'']+\.drv' $STATE_DIR/build-output.log
   ```

2. **If `nix log` references found** → classification: `DERIVATION_BUILD_FAILURE`.  Go to **step 4a**.

3. **If no `nix log` references found**, search for hash mismatch:
   ```bash
   rg -A 10 'hash mismatch in fixed-output derivation' $STATE_DIR/build-output.log
   ```
   If found → classification: `HASH_MISMATCH`. Go to **step 5**, read `reference/hash-mismatch.md`.

4. **If still no matches** → classification: `EVAL_ERROR`. Go to **step 4b**.

---

### 4a. Classify Derivation Build Failure

The derivation logs from step 3 contain the raw build output. Search for error patterns and classify:

1. **Search for specific error patterns** in the derivation log:
   ```bash
   nix log <derivation-path> 2>&1 | rg -A 50 -B 50 'error:|FAIL|fatal error'
   ```
2. **Read more lines** if that wasn't enough:
   ```bash
   nix log <derivation-path> 2>&1 | tail -n 500
   ```

3. **Subclassify the `DERIVATION_BUILD_FAILURE`:**
   - `BUILD_TEST_FAILURE` — `FAIL`, `FAILED`, `test.*failed`, `tests failed`, `doCheck`, `checkPhase`, pytest/meson/cargo test runner output
   - `BUILD_COMPILATION_ERROR` — `error:` from gcc/g++/clang/cc, `-Werror`, `undefined reference to`, `undefined symbol`, `fatal error: ... No such file or directory` (missing header), `cannot find -l...`
   - `BUILD_MISSING_DEPENDENCY` — `command not found`, `No such file or directory` (for a build tool/binary), `Package '...' not found` (pkg-config), `Could not find a configuration file for package`, `ModuleNotFoundError`, `ImportError`
   - `BUILD_FLAG_ERROR` — `CMake Error at`, `CMake Error:`, `ERROR: Problem encountered:` (meson), `meson.build:.*ERROR`, `configure: error:`, `Unknown option:`
   - `BUILD_RESOURCE_ISSUE` — `Killed`, `killed by signal`, `out of memory`, `Cannot allocate memory`, `No space left on device`, `connection refused`, `Connection timed out`
   - `BUILD_UNKNOWN` — none of the above patterns match

   Go to **step 5**.

---

### 4b. Classify Evaluation Error

Read the build output directly:
```bash
tail -n 150 $STATE_DIR/build-output.log
```

The output contains the nix evaluator error. Subclassify:

- `EVAL_ATTR_MISSING` — `error: attribute '...' missing`, `error: attribute '...' not found`, `error: undefined variable '...'`
- `EVAL_TYPE_ERROR` — `error: value is a ... while a ... was expected`, `error: cannot coerce ... to a string`
- `EVAL_INFINITE_RECURSION` — `error: infinite recursion encountered`
- `EVAL_ASSERTION` — `error: assertion '...' failed`, `Failed assertions:`
- `EVAL_SYNTAX` — `error: syntax error, unexpected ...`
- `EVAL_OTHER` — any other `error:` from the evaluator

Go to **step 5**.

---

### 5. Analyze and Determine Fix

Read the reference document for the classified error type:

| Classification | Reference Document |
|---------------|-------------------|
| `EVAL_ATTR_MISSING` | `reference/eval-attr-missing.md` |
| `EVAL_TYPE_ERROR` | `reference/eval-type-error.md` |
| `EVAL_INFINITE_RECURSION` | `reference/eval-infinite-recursion.md` |
| `EVAL_ASSERTION` | `reference/eval-assertion.md` |
| `EVAL_SYNTAX` | `reference/eval-syntax.md` |
| `EVAL_OTHER` | `reference/research.md` |
| `HASH_MISMATCH` | `reference/hash-mismatch.md` |
| `BUILD_TEST_FAILURE` | `reference/test-failures.md` |
| `BUILD_COMPILATION_ERROR` | `reference/compilation-errors.md` |
| `BUILD_MISSING_DEPENDENCY` | `reference/missing-dependencies.md` |
| `BUILD_FLAG_ERROR` | `reference/build-flags.md` |
| `BUILD_RESOURCE_ISSUE` | `reference/builder-issues.md` |
| `BUILD_UNKNOWN` | `reference/build-unknown.md` |

**Circular fix detection:**
```bash
if claude-NixOSBuild-check-attempt "$STATE_DIR" "<error_signature>" "<classification>"; then
  # Already tried — try an alternative fix or go to step 8 (Report Failure)
fi
```

**`BUILD_RESOURCE_ISSUE`:** Try flag adjustments (see `reference/builder-issues.md`) BEFORE code fixes.

---

### 6. Apply Fix

Read the appropriate reference document for the fix type (see table above). Apply the fix following the patterns in that document. 
All file edits must use absolute paths within the worktree: `@home@/repos/nixos-config/<worktree>/patches/default.nix`, etc.

**Comment style (CRITICAL):**
```nix
# NixOSBuild AUTOFIX
# Package name: Brief description of fix
# Error details: what failed and why
# Fix explanation: what this does and why it works
```

**All fixes must:**
- NEVER remove a package
- Stage all changed files
- Include comments documenting the reason
- Pass the lint hook: `pre-commit run -a` 

---

### 7. Retry Build

1. **Record** in attempt history:
   ```bash
   claude-NixOSBuild-record-attempt "$STATE_DIR" "<error_signature>" "<classification>"
   ```

2. **Return to step 2**

---

### 8. Report Results

Read [reference/report-formats.md](../reference/report-formats.md) and output the appropriate format (success or failure).

**On success**, commit all accumulated fixes:

1. **Stage changed files** (specific files, not `git add -A`). Use absolute paths:
   ```bash
   git -C @home@/repos/nixos-config/<worktree> add patches/default.nix patches/fixes/<file> modules/<path>
   ```

2. **Commit:**
   ```bash
   git -C @home@/repos/nixos-config/<worktree> commit -m "$(cat <<'EOF'
   fix(<scope>): <short description>

   <error type>: <brief error description>
   <fix applied>: <brief fix description>
   EOF
   )"
   ```

3. **If commit fails** (lint hook): re-stage fixed files, create a NEW commit (never `--amend`).

4. **Clean up state directory:**
   ```bash
   rm -rf "$STATE_DIR"
   ```

**On failure**, do not commit. The working tree retains uncommitted changes for the user to inspect. Do NOT clean up `$STATE_DIR` — the logs are useful for debugging.

---

## Guidelines

- NEVER remove a package to fix a build error — the user added it for a reason. Fix the package instead (patch, override, version bump, disable tests, etc.)
- Every fix MUST include the comment `# NixOSBuild AUTOFIX` as the first line of the comment block
- Prefer minimal fixes over invasive changes
- All file paths must be absolute, using `@home@/repos/nixos-config/<worktree>/` as the base
