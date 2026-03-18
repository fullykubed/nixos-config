# Nightly Auto-Upgrade

`modules/common/nightly-auto-upgrade/default.nix` defines a systemd timer that automatically upgrades the system every night by cloning and applying the latest `main` branch.

## How it works

1. At 1:00 AM, `nixos-auto-upgrade.timer` starts `nixos-auto-upgrade.service`
2. The service shallow-clones `main` from `git@github.com:fullykubed/nixos-config.git` into a temporary directory
3. Verifies the latest commit is signed by a trusted SSH key (from `secrets/git-ssh-key.pub`). If verification fails, the service sends a Pushover notification and exits without building
4. Runs `nixos-rebuild switch --flake <clone>#<hostname> --accept-flake-config`
4. On success: cleans up the clone directory, exits silently
5. On failure: checks whether the system profile changed (activation failure vs build failure). If the profile changed, runs `nixos-rebuild switch --rollback` to revert. Sends a Pushover notification via `notify-if-away --force`, then cleans up

The timer runs before the vulnix scanner (2:00 AM) so vulnerability scans reflect the latest applied configuration.

## Systemd units

### `nixos-auto-upgrade.service` — Clone and rebuild from upstream main

- **Type**: oneshot
- **After**: `agenix.service` (secrets must be decrypted)
- **restartIfChanged**: false (prevents `switch-to-configuration` from killing the service when its own definition changes during activation)
- **Environment**: `GIT_SSH_COMMAND` set to use the agenix-managed git SSH key

### `nixos-auto-upgrade.timer` — Nightly schedule

- **OnCalendar**: `*-*-* 01:00:00` (1:00 AM daily)
- **Persistent**: true (runs on next boot if the machine was off at 1 AM)
- **WakeSystem**: true (wakes from sleep to run)

The service has no `wantedBy` — it is only started by the timer or manually via `un -U`.

## Manual trigger

Run the same upgrade logic on demand:

```bash
un -U             # triggers the systemd service and follows journal output
```

This starts the service via `systemctl start` and streams its journal output so you can watch progress. The command exits with the service's exit code.

## Failure handling

The service distinguishes between three failure modes:

**Signature verification failure** — The latest commit on `main` is unsigned or signed by an untrusted key. The service refuses to build, sends a Pushover notification ("Commit signature verification failed"), and exits. Nothing on the system changes.

**Build failure** — `nixos-rebuild` fails before updating the system profile. Nothing changed on the system. The service sends a Pushover notification and exits.

**Activation failure** — The system profile was updated but `switch-to-configuration` failed partway through. The service detects the profile change, runs `nixos-rebuild switch --rollback` to revert to the previous generation, sends a Pushover notification, and exits.

In both cases the temporary clone directory is cleaned up via `trap ... EXIT`.

## Monitoring

```bash
systemctl status nixos-auto-upgrade.service    # last run status
systemctl status nixos-auto-upgrade.timer      # next scheduled run
journalctl -u nixos-auto-upgrade.service       # full log history
journalctl -u nixos-auto-upgrade.service -b    # logs from current boot
```

## Key files

| File | Purpose |
|------|---------|
| `modules/common/nightly-auto-upgrade/default.nix` | Module definition: service, timer, upgrade script |
| `modules/common/scripts/scripts/un.sh` | `-U`/`--upgrade` flag triggers the service |
| `modules/common/away-notify/default.nix` | `notify-if-away` used for failure notifications |
| `modules/common/git/default.nix` | Declares `age.secrets.git-ssh-key` used for SSH clone |
