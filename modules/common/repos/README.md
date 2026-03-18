# Declarative Repository Sync

Manages Git repositories declaratively via NixOS options. Repos are cloned using the bare-clone + worktree layout with SSH authentication.

## Usage

```nix
repos.nixos-config = {
  url = "git@github.com:fullykubed/nixos-config.git";
  path = "nixos-config";
  branch = "main";
  files.".envrc" = "use flake\n";
};
```

### Per-repo options

| Option          | Type           | Default | Description                                                        |
|-----------------|----------------|---------|--------------------------------------------------------------------|
| `url`           | string         |         | SSH clone URL                                                      |
| `path`          | string         |         | Directory name under `~/repos/`                                    |
| `branch`        | string         |         | Default branch — a worktree is created for it                      |
| `files`         | attrsOf string | `{}`    | Files placed in the branch worktree directory and excluded from git |
| `workmuxConfig` | attrs          | `{}`    | Additional workmux config deep-merged with `{main_branch = branch}`|

## Directory layout (per repo)

```
~/repos/<path>/
├── .bare/                    # Bare git repository
│   ├── .repo-sync-managed    # Marker file
│   └── info/exclude          # Git excludes for declared files
├── .envrc                    # direnv config (GIT_DIR / GIT_WORK_TREE)
└── <branch>/                 # Worktree for the default branch
    ├── .workmux.yaml         # Generated workmux config
    └── <declared files>      # Files from the `files` option
```

## What happens on activation

1. **New repos** are cloned via `repo-sync-clone`, then a marker is written and a detached tmux session is started
2. **Existing managed repos** are left alone (Home Manager updates `.envrc`, `.workmux.yaml`, and declared files)
3. **Existing non-managed repos** (no marker file) cause an error
4. **Declared files** and `.workmux.yaml` are added to `.bare/info/exclude`
5. **Removed repos** (present in previous state but absent from current config) are deleted

Home Manager manages `.envrc`, `.workmux.yaml`, and declared files via `home.file`. The activation script only handles git operations and state tracking (`~/.local/state/repo-sync/managed-repos.json`).

## Systemd timer

A user-level systemd timer runs `repo-sync-fetch` every 30 minutes (first run 5 minutes after login), fetching all managed repos.
