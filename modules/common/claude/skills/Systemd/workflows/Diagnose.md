# Diagnose Workflow

Perform a structured systemd diagnostic: check failed units, query journal logs, inspect specific services, analyze boot performance, and review timer state.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Determine Scope

Inspect the argument passed to the skill:

| Argument | Starting Step |
|----------|---------------|
| `diagnose` (no unit) | Step 2 — broad system-wide diagnostic |
| `diagnose <unit>` | Step 3 — service-specific diagnostic for `<unit>` |
| `boot` | Step 5 — boot analysis only |
| `timers` | Step 6 — timer status only |

---

### 2. Check for Failed Units

Run the following to get an overview of all failed units:

```bash
systemctl --failed
```

| Situation | Action |
|-----------|--------|
| No failed units reported | Note "No failed units" and proceed to Step 3 |
| One or more failed units listed | Record the unit names; proceed to Step 3 for each failed unit |

To reset a unit's failed state after it has been inspected and the underlying issue is resolved, the user would run `systemctl reset-failed <unit>` — but do NOT run this automatically; it discards failure information.

---

### 3. Check Service Status

If a specific unit was provided in the argument, use that. Otherwise use the failed units found in Step 2 (if any), or ask the user which service to inspect.

```bash
systemctl status <unit>
```

This shows:
- Active state (`active (running)`, `inactive (dead)`, `failed`, `activating`, `deactivating`)
- Main PID and memory usage
- The last few journal lines for the unit
- Timestamps for when the unit last started/stopped

To check liveness and enablement separately:

```bash
systemctl is-active <unit>
systemctl is-enabled <unit>
```

| Situation | Action |
|-----------|--------|
| Unit is `active (running)` | Service is healthy; check journal for recent errors if user reported issues |
| Unit is `failed` | Proceed to Step 4 — query full journal for this unit |
| Unit is `inactive (dead)` | Check if it should be running; check `is-enabled` to see if it is a oneshot or disabled |
| Unit is `activating` or `deactivating` | Wait and re-run `systemctl status` in a moment; unusual if stuck |

To list all loaded units to find the correct name:

```bash
systemctl list-units --type=service
```

To list all installed unit files including disabled ones:

```bash
systemctl list-unit-files --type=service
```

---

### 4. Query Journal Logs

Query the journal for the unit identified in Step 3. Always start with recent logs:

```bash
journalctl -u <unit> --no-pager -n 100
```

For more context going further back:

```bash
journalctl -u <unit> --no-pager --since "1 hour ago"
```

To filter to only error-level and above messages across the entire journal (not unit-scoped):

```bash
journalctl -p err --no-pager -n 100
```

To see the journal since the last boot:

```bash
journalctl -b --no-pager -n 200
```

| Situation | Action |
|-----------|--------|
| Logs show a clear error message | Analyze the error and suggest a fix or further investigation |
| Logs show the service crashing or restarting | Look for the crash reason (signal, exit code, OOM); report to the user |
| Logs show "permission denied" or "no such file" | Configuration or file system issue; identify the missing path or resource |
| Logs are empty for the unit | The unit may not have run since boot; check `systemctl status` timestamps |
| Logs are too verbose to read | Narrow with `--since` or `-p err` to filter to errors only |

---

### 5. Boot Analysis

Analyze overall boot time and identify slow units:

```bash
systemd-analyze
```

This shows total boot time broken down into firmware, loader, kernel, and userspace.

To see which units took the longest:

```bash
systemd-analyze blame
```

To trace the critical path through unit dependencies:

```bash
systemd-analyze critical-chain
```

To trace the critical path for a specific unit:

```bash
systemd-analyze critical-chain <unit>
```

| Situation | Action |
|-----------|--------|
| Boot time is acceptable (under ~15s userspace) | Report metrics; no action needed |
| A single unit dominates `blame` output | Identify that unit; check its journal logs (Step 4) |
| `critical-chain` shows long `@` timestamps | The unit at the top of the chain added that latency; investigate it |
| Boot time regression after a change | Compare blame output before/after change; identify the newly slow unit |

---

### 6. Timer Status

List all active and loaded timers:

```bash
systemctl list-timers
```

This shows each timer, its last trigger time, next trigger time, and the unit it activates.

To inspect a specific timer:

```bash
systemctl status <timer>.timer
```

To check the journal for the service the timer activates:

```bash
journalctl -u <service>.service --no-pager -n 50
```

| Situation | Action |
|-----------|--------|
| Timer shows `n/a` for last trigger | Timer has never fired; check if it is enabled and the calendar expression is valid |
| Timer last triggered long ago (unexpectedly) | The service it activates may have failed; run `systemctl status <service>` |
| Timer next trigger is in the past | systemd may have missed a run; check if the system was suspended or off |
| Timer is not listed | Check `systemctl list-unit-files --type=timer` to see if it exists and is enabled |

---

### 7. Report Findings

After completing the relevant steps, provide a structured summary:

1. **System health**: Were any failed units found? What is their status?
2. **Journal findings**: What errors or anomalies appeared in the logs?
3. **Boot performance**: Is boot time normal? Are there slow units?
4. **Timer health**: Are timers firing as expected?
5. **Recommended next steps**: Specific actions the user can take to resolve identified issues.

## Guidelines

- Never run commands with `sudo` or any privilege escalation — all commands in this workflow are unprivileged and rely on the user's group membership (e.g., `systemd-journal` group for full journal access)
- If journal output is truncated due to group membership, inform the user they may need to be added to the `systemd-journal` group or use `loginctl` to check their session
- Do not restart, stop, or start services — this workflow is read-only and diagnostic only
- Do not reset failed states with `systemctl reset-failed` unless explicitly asked by the user
- Always use `--no-pager` with `journalctl` to avoid interactive pager output
- Prefer `-n <lines>` over unbounded queries to keep output manageable
