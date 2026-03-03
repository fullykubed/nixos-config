# Fix Type: Builder / Resource Issues

Failures caused by remote builder connectivity, resource exhaustion, or Nix daemon issues — not code problems.

## Error Signatures

- `connection refused`
- `builder timeout`
- `remote builder unavailable`
- `ssh connection failed`
- `error: cannot build on ...`
- `out of disk space`
- `killed` (OOM killer)

## Fix Strategies

These are **nix build flag adjustments**, not code changes. Try these BEFORE attempting code fixes.

### Disable Remote Builders

```bash
nix build --no-link --impure --builders "" .#nixosConfigurations.<hostname>.config.system.build.toplevel
```

### Adjust Parallelism

Increase concurrent jobs (if bottlenecked on single job):
```bash
nix build --no-link --impure --max-jobs 2 .#nixosConfigurations.<hostname>.config.system.build.toplevel
```

Decrease concurrent jobs (if running out of memory):
```bash
nix build --no-link --impure --max-jobs 1 .#nixosConfigurations.<hostname>.config.system.build.toplevel
```

### Notes

- These are retry strategies, not code fixes — track as "retry with different flags" in attempt history
- If disabling remote builders fixes the issue, the problem is infrastructure, not code
- If adjusting parallelism fixes the issue, consider updating the default in `un.sh`
