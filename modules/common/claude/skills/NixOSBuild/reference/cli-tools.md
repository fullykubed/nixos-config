# CLI Tools

## Attempt History

These tools manage the build attempt history used for circular fix detection. All take a `<state_dir>` argument returned by `init-history`.

### `claude-NixOSBuild-init-history <worktree>`

Initialize the state directory for a build session. Creates `/tmp/nixos-build/<worktree>/` with an empty `attempts.log`.

**Returns:** The state directory path (stdout).

### `claude-NixOSBuild-record-attempt <state_dir> <error_signature> <classification>`

Record a fix attempt. Appends a timestamped entry to `attempts.log`.

**Arguments:**
- `<state_dir>` — Path returned by `init-history`
- `<error_signature>` — Unique identifier for the error (e.g., package name + error type)
- `<classification>` — Error classification (e.g., `BUILD_TEST_FAILURE`, `EVAL_ATTR_MISSING`)

### `claude-NixOSBuild-check-attempt <state_dir> <error_signature> <classification>`

Check if an error+classification pair has already been attempted (circular fix detection).

**Exit code:**
- `0` — Already tried (circular — try an alternative fix or report failure)
- `1` — Not yet tried (safe to proceed)

### `claude-NixOSBuild-list-attempts <state_dir>`

Print all recorded attempts (TSV: timestamp, signature, classification).

### `claude-NixOSBuild-attempt-count <state_dir>`

Print the number of recorded attempts.
