# System Systemd Services

This guide covers patterns for defining systemd **system** services and timers in NixOS modules. System services are managed by the system service manager (PID 1) and run as root or a dedicated system user.

For services that need a user session (desktop notifications, Wayland/X11, `$HOME` access), see [User services](user.md) instead.

## Codebase defaults

`modules/common/systemd/` applies these defaults to every system service via `lib.mkDefault`, overridable per-service:

**`RemainAfterExit = true`** — Oneshot services stay in the "active" state after their command exits rather than transitioning to "inactive". This makes `systemctl status` reflect the outcome of the last run and lets other units use `After=<unit>.service` as a dependency gate. Set `RemainAfterExit = false` explicitly for maintenance tasks that should show as inactive after running (e.g. a USB device reset).

**`LogFilterPatterns`** — A set of patterns that redact common secret shapes from the journal before they are stored: AWS key prefixes, GitHub tokens, private key headers, JWTs, Google API keys, Slack tokens, age secret keys, and Vault tokens. No per-service configuration is needed.

## Service types

| Type | Use when | Notes |
|---|---|---|
| `simple` | Long-running daemon — process stays alive indefinitely | Default if `Type` is omitted. Systemd considers the service ready as soon as the process starts. |
| `oneshot` | Task that runs to completion and exits — scripts, polls, uploads, setup steps | Systemd waits for the process to exit before marking the service active. Set `restartIfChanged = false` (see below) or it will block `nixos-rebuild switch`. |
| `notify` | Long-running daemon that signals readiness via `sd_notify` | Systemd waits for the daemon to send a ready notification before marking it active. More precise than `simple` for services with a slow startup phase. |

When in doubt, use `oneshot` for scripts and tasks, `simple` for daemons.

## Oneshot service

A task that runs once and exits (e.g. a setup step, a poll, an upload) uses `Type = "oneshot"`.

```nix
systemd.services.my-task = {
  description = "Run my-task once";
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${myScript}/bin/my-task";
  };
};
```

### `restartIfChanged = false` and `reloadIfChanged = true`

Oneshot services must always set `restartIfChanged = false`. This is a NixOS module option (not a systemd option) that controls whether `nixos-rebuild switch` restarts the service when its definition changes.

Without it, activating a new system generation will re-run the service inline during the switch. Since a oneshot service runs to completion before systemd considers it done, this **blocks the entire rebuild** until the service finishes — which for a long-running task like a build, upload, or upgrade can mean minutes or indefinitely.

Whenever `restartIfChanged = false` is set, **always pair it with `reloadIfChanged = true`**. This ensures that when the unit file changes (e.g. a script is updated or a dependency store path changes), systemd reloads the unit on the next switch — so the new configuration takes effect on the next timer invocation without waiting for a manual intervention. Without it, a stale unit can persist across rebuilds undetected.

```nix
systemd.services.my-task = {
  description = "Do something once";
  restartIfChanged = false;   # never re-run during nixos-rebuild switch
  reloadIfChanged = true;     # but do pick up unit changes on switch
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${myScript}/bin/my-task";
  };
};
```

Long-running daemons generally do want to restart when their config changes, so `restartIfChanged` is most important for oneshot services and their timers.

## Timer-activated service

Use a timer to run a oneshot service on a schedule. The timer and service share the same name:

```nix
systemd.services.my-poller = {
  description = "Poll something";
  restartIfChanged = false;
  reloadIfChanged = true;
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${myScript}/bin/my-poller";
  };
};

systemd.timers.my-poller = {
  description = "Poll something every 60s";
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnBootSec = "30s";       # first run: 30s after boot
    OnUnitActiveSec = "60s"; # subsequent runs: 60s after the last run
  };
};
```

The service itself does **not** need `wantedBy` — the timer activates it.

`OnUnitActiveSec` measures from the last time the unit became active (i.e. last successful run). If the service fails, systemd falls back to `OnUnitInactiveSec` if set, or the timer may fire sooner. For most polling services `OnUnitActiveSec` is the right choice.

## Ordering dependencies

| Option | Meaning |
|---|---|
| `after` | Start this unit only after the listed units have finished starting. No effect on whether those units are started. |
| `wants` | Pull in the listed units when this one starts. Failure of a wanted unit does not prevent this unit from starting. |
| `requires` | Like `wants`, but this unit fails if any required unit fails to start. |
| `wantedBy` | The reverse of `wants`: add this unit to another unit's `wants` list. Used to hook into boot targets. |

Common targets:

| Target | When to use |
|---|---|
| `multi-user.target` | Long-running services that should start at boot |
| `network.target` | Service needs the network stack to exist (interfaces up, no IP required) |
| `network-online.target` | Service needs a working IP address (DHCP completed on at least one interface); pair with `nss-lookup.target` if hostname resolution is also needed |
| `nss-lookup.target` | Service needs DNS resolution to work; always pair with `network-online.target` (see below) |
| `sleep.target` | Service should run before suspend / after resume |
| `timers.target` | Timers: hooks the timer into the boot sequence |

## Network and DNS readiness

If your service reaches out to any hostname over the network, it almost certainly needs both `network-online.target` **and** `nss-lookup.target`. `network-online.target` alone is not enough — it only guarantees an IP address exists, not that DNS queries work. In practice most services that connect to an external API, a remote server, or any URL by hostname will fail silently on early boots if `nss-lookup.target` is omitted.

The standard boilerplate for any network-dependent service is:

```nix
after = [ "network-online.target" "nss-lookup.target" ];
wants = [ "network-online.target" "nss-lookup.target" ];
```

### `network-online.target`

Reached when the network manager (NetworkManager, networkd) reports that initial configuration is complete — typically once at least one interface has an IP address.

### `nss-lookup.target`

Reached when the local DNS resolver daemon is running. On this system `dnscrypt-proxy` declares `Before=nss-lookup.target`, so adding this dependency ensures the resolver process is up before your service starts.

This does **not** guarantee that DNS queries will succeed — the resolver may be running but have no upstream DNS servers yet if DHCP hasn't completed (see below).

```nix
after = [ "network-online.target" "nss-lookup.target" ];
wants = [ "network-online.target" "nss-lookup.target" ];
```

### Verifying DNS with `ExecCondition`

Some boots have a race where `network-online.target` is satisfied but the DHCP lease hasn't arrived yet, leaving the DNS resolver with no upstream servers. A service that needs DNS should verify it with `ExecCondition`.

`ExecCondition` runs before the main service command. If it exits 1–254, systemd **skips** the service (status: `inactive`, not `failed`) rather than marking it as an error. For timer-activated services this is the correct behaviour — the timer retries on its normal schedule without polluting `systemctl --failed`.

```nix
systemd.services.my-poller = {
  description = "Poll the Hetzner API";
  after = [ "network-online.target" "nss-lookup.target" ];
  wants = [ "network-online.target" "nss-lookup.target" ];

  serviceConfig = {
    Type = "oneshot";
    # Skip (not fail) if DNS is not yet working. The timer retries shortly.
    ExecCondition = "${pkgs.getent}/bin/getent ahosts api.example.com";
    ExecStart = "${myScript}/bin/my-poller";
  };
};
```

`getent ahosts` exercises the full NSS resolution stack — the same path the application uses — so a successful exit confirms DNS actually works end-to-end.

Use the specific hostname your service needs as the condition target. This keeps the check meaningful: if DNS works for that host, the service will succeed; if not, the skip is justified.

**`ExecCondition` vs `ExecStartPre`**

| | `ExecCondition` | `ExecStartPre` |
|---|---|---|
| Exit 1–254 | Service **skipped** (inactive, not failed) | Service **fails** |
| Exit 255 or signal | Service **fails** | Service **fails** |
| Exit 0 | Main command runs | Main command runs |
| Use when | Prerequisite may legitimately be unmet | Prerequisite must be met; failure is an error |

## Runtime directories and state

Use `RuntimeDirectory` for transient data that should be cleared on reboot (placed under `/run/`). Use `StateDirectory` for persistent data (placed under `/var/lib/`):

```nix
serviceConfig = {
  Type = "oneshot";
  RuntimeDirectory = "my-service";           # creates /run/my-service, owned by the service user
  RuntimeDirectoryPreserve = "yes";          # keep the directory between runs (don't clear on exit)
  StateDirectory = "my-service";             # creates /var/lib/my-service
};
```

## Injecting secrets

Secrets decrypted by agenix are available at their configured path at service start time. Pass them via environment variables or file paths:

```nix
environment = {
  API_TOKEN_FILE = config.age.secrets.my-api-token.path;
};
```

Read the file at runtime in the script rather than expanding the token into the environment directly — this avoids the token appearing in `systemctl show` output or the process environment.

To prevent the service from inheriting environment variables from the system, clear the environment file list:

```nix
serviceConfig = {
  EnvironmentFile = ""; # clear any inherited env
};
```

## PATH in services

By default systemd services have a minimal PATH. Use the `path` option to add packages:

```nix
systemd.services.my-service = {
  path = [ pkgs.curl pkgs.jq myScript ];
  script = "my-script";
};
```

Or reference binaries by their full store path in `ExecStart`/`ExecCondition`:

```nix
serviceConfig.ExecStart = "${pkgs.curl}/bin/curl https://example.com";
```

## Running as a non-root user

```nix
serviceConfig = {
  User = "my-user";
  Group = "my-group";
  DynamicUser = true; # systemd allocates a transient UID automatically
};
```

`DynamicUser = true` is convenient for services that don't need a stable UID and don't own persistent files outside `StateDirectory` (which systemd chowns automatically).

## Checklist

When adding a new system service, verify each item before deploying:

**Type and scope**
- [ ] Service type chosen (`simple`, `oneshot`, `notify`) — see the types table above
- [ ] System vs [user service](user.md) decided — does it need root / boot-time start, or user session / D-Bus access?
- [ ] Oneshot services have `restartIfChanged = false` to avoid blocking `nixos-rebuild switch`
- [ ] Any service with `restartIfChanged = false` also has `reloadIfChanged = true` so unit changes still take effect on switch

**Startup ordering**
- [ ] `wantedBy` set if the service should start automatically (`multi-user.target`)
- [ ] If the service connects to any hostname: `after` and `wants` include both `network-online.target` and `nss-lookup.target`
- [ ] If the service communicates over Tailscale (MagicDNS hostnames or Tailscale IPs): `after` and `wants` also include `tailscale-autoconnect.service`
- [ ] If timer-activated and needs network: `ExecCondition` verifies DNS resolves before the main command runs
- [ ] Timer has `wantedBy = [ "timers.target" ]`

**Security**
- [ ] Service does not run as root unless necessary — use `User`/`Group` or `DynamicUser = true`
- [ ] Secrets are read from their file path at runtime, not expanded into `environment` or `ExecStart`
- [ ] `EnvironmentFile = ""` set if the service should not inherit system environment variables

**Error handling**
- [ ] Scripts use `set -euo pipefail` (automatic with `pkgs.writeShellApplication`) so failures are never silently swallowed
- [ ] Transient prerequisite failures (DNS not ready, network unavailable) use `ExecCondition` to skip the run — not `exit 0` inside the script, which would hide the failure from systemd entirely
- [ ] `|| true` and `2>/dev/null` are not used to suppress errors unless the failure is genuinely inconsequential and a comment explains why

**Runtime**
- [ ] Binaries referenced by full store path (`${pkgs.foo}/bin/foo`) or declared in `path = [ ... ]`
- [ ] Transient scratch data uses `RuntimeDirectory` (`/run/`); persistent data uses `StateDirectory` (`/var/lib/`)
- [ ] Long-running daemons have `Restart = "on-failure"` so they recover from crashes

**Verification**
- [ ] `systemctl status <unit>` shows active after deploy
- [ ] `journalctl -u <unit>` shows no unexpected errors on first run

## Real examples in this codebase

| Module | Pattern |
|---|---|
| `modules/common/remote-builders/` | Oneshot + timer + `ExecCondition` for DNS check |
| `modules/common/nightly-auto-upgrade/` | Oneshot + timer + `requires` for network and Tailscale |
| `modules/common/mitmproxy-credential-proxy/` | Long-running daemon with `ExecStartPre` and `Restart` |
| `modules/common/wakeup/` | Oneshot triggered by `sleep.target` |
