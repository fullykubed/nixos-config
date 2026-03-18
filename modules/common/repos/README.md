# Declarative Repository Sync

Manages Git repositories declaratively via NixOS options. Repos are cloned using the bare-clone + worktree layout with SSH authentication.

## Usage

```nix
repos.nixos-config = {
  url = "git@github.com:fullykubed/nixos-config.git";
  path = "nixos-config";
  branch = "main";
  tmuxSession = "nixos-config";
  direnv = true;
};
```

### Per-repo options

| Option          | Type           | Default | Description                                                                  |
|-----------------|----------------|---------|------------------------------------------------------------------------------|
| `url`           | string         |         | SSH clone URL                                                                |
| `path`          | string         |         | Directory name under `~/repos/`                                              |
| `branch`        | string         |         | Default branch — a worktree is created for it                                |
| `tmuxSession`   | string         |         | Name of the detached tmux session for this repo                              |
| `files`         | attrsOf string | `{}`    | Files placed in the branch worktree directory and excluded from git          |
| `env`           | attrsOf string | `{}`    | Key-value pairs written to `.env`; values can be agenix secret paths         |
| `direnv`        | bool           | `false` | Adds `direnv allow` as a workmux `post_create` hook and `.envrc` to `files.copy` |
| `workmuxConfig` | attrs          | `{}`    | Additional workmux config deep-merged with `{main_branch = branch}`          |

## Directory layout (per repo)

```
~/repos/<path>/
├── .bare/                    # Bare git repository
│   └── info/exclude          # Git excludes for managed files
├── .envrc                    # direnv config (GIT_DIR / GIT_WORK_TREE)
└── <branch>/                 # Worktree for the default branch
    ├── .workmux.yaml         # Generated workmux config
    ├── .env                  # Generated from `env` option (if set)
    └── <declared files>      # Files from the `files` option
```

## What happens on activation

Each repo has its own activation entry (`repoSync-<name>`) that runs before `linkGeneration`:

1. **Path change** — if the repo moved, `mv` the old directory to the new path
2. **New repos** — `git clone --bare`, configure fetch refspec, create worktree, start tmux session
3. **Existing repos** (has `.bare/`) — update remote URL, update fetch refspec, handle branch/worktree changes
4. **Existing non-bare directory** — error (won't clobber unknown directories)
5. **Branch change** — errors if the old worktree is dirty, otherwise removes it and creates the new one
6. **Session rename** — `tmux rename-session` if the session name changed
7. **`.env` generation** — writes key-value pairs with `0600` permissions; values that are file paths are read at activation time (for agenix secrets)
8. **Git excludes** — `.workmux.yaml`, `.env`, and declared file names are added to `.bare/info/exclude`
9. **State tracking** — per-repo state saved to `~/.local/state/repo-sync/<name>.json`

A separate `repoSyncCleanup` activation entry removes repos that were deleted from config (directory, tmux session, and state file).

Home Manager manages `.envrc`, `.workmux.yaml`, and declared files via `home.file`. The activation script only handles git operations, `.env` generation, and state tracking.

## Systemd timers

Per-repo user-level systemd timers run `repo-sync-fetch` every 30 minutes (first run 5 minutes after login). Each repo has its own `repo-sync-fetch-<name>.service` and timer.

## State management

Per-repo state is stored at `~/.local/state/repo-sync/<name>.json` containing:

```json
{"path": "/home/user/repos/foo", "session": "foo", "branch": "main"}
```

This enables detecting path, session, and branch changes across activations.
