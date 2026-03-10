# Deploying Configuration Changes

## Quick start

Run `un` from anywhere inside the repo:

```bash
un            # rebuild and switch
un -b         # rebuild boot configuration only
un -u         # update flake inputs first
```

`un` is installed system-wide (via `modules/common/scripts/`) and auto-detects the repo root, escalates with `doas`, and pipes output through `nix-output-monitor`.

## Fallback: calling un.sh directly

If you have edited `un.sh` itself and haven't yet rebuilt, the installed `un` on your PATH is stale. Call the script directly:

```bash
doas ./modules/common/scripts/scripts/un.sh
```

## Options

| Flag | Description |
|------|-------------|
| `-b`, `--boot` | Rebuild boot configuration only |
| `-B N`, `--builders N` | Use N regular remote builders (0 disables all) |
| `-P N`, `--big-builders N` | Use N big-parallel remote builders |
| `-j N`, `--jobs N` | Max concurrent derivation builds (default: 1) |
| `-o`, `--offline` | Build without network access |
| `-u`, `--update` | Update flake inputs before rebuilding |
| `--no-impure`, `--copy` | Copy config to `/etc/nixos` instead of building in-place |
| `--no-nom` | Disable nix-output-monitor |

## Examples

```bash
un -B 3 -P 1      # 3 regular + 1 big-parallel remote builder
un -B 0            # disable all remote builders
un -u -b           # update flake inputs, rebuild boot config
un --copy          # copy to /etc/nixos first (old behavior)
```

## Deploying with AI autofix

`una` is for deploying changes from a git worktree. It detects the current worktree and hostname, then invokes Claude Code's NixOSBuild skill which builds the configuration and automatically fixes any build errors in a loop until it succeeds.

```bash
una               # build and auto-fix from the current worktree
```

`una` must be run from inside the nixos-config repo or one of its worktrees.
