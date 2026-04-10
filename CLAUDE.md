# CLAUDE.md

@docs/architecture.md

## Build Output Logging

When running long-running build commands (`nix build`, `cargo build`, `make`, etc.), always redirect output to a temp log file rather than piping to `tail`. Use:

```bash
LOG=$(mktemp --suffix=.build.log)
nix build ... > "$LOG" 2>&1
```

Always print the log path so progress can be monitored (`tail -n 50 "$LOG"`) if the build appears stalled. Never truncate build output with `| tail` or `| head` — the full log must be preserved to diagnose failures and stalls.

