# User Systemd Services

This guide covers patterns for defining systemd **user** services and timers inside Home Manager modules. User services are managed by the per-user service manager instance and run as the logged-in user.

For services that need to run at boot, access system resources, or read agenix secrets, see [System services](system.md) instead.

## Codebase defaults

`modules/common/systemd/` applies these defaults to the user service manager:

**`DefaultLimitNOFILE=65536`** — The open file descriptor limit is raised from 1024 to 65536. This prevents failures in services that open many files or connections — language servers, sync daemons, watch-mode tools — without requiring per-service `LimitNOFILE` overrides.

## Syntax

User services are defined inside `home-manager.users.${config.username}` and use **capitalised section names** matching raw systemd unit file syntax — unlike system services, which use lowercase Nix-style attributes:

```nix
home-manager.users.${config.username} = {
  systemd.user.services.my-daemon = {
    Unit = {
      Description = "My daemon";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${myPackage}/bin/my-daemon";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
};
```

The section names (`Unit`, `Service`, `Install`, `Timer`) map directly to unit file sections.

## Targets

| Target | When to use |
|---|---|
| `default.target` | Service should start on login (equivalent of `multi-user.target` for user sessions) |
| `graphical-session.target` | Service needs a graphical session to be running |
| `sway-session.target` | Service needs Sway specifically (Wayland env vars exported) |
| `timers.target` | User timers |

Use `Unit.After` to order relative to a target without pulling it in. Use `Install.WantedBy` to start the service automatically when the target is reached.

For services that should stop when the compositor exits (e.g. Sway-specific daemons), use `Unit.PartOf` instead of `Unit.After`:

```nix
Unit = {
  PartOf = [ "sway-session.target" ];
  After = [ "sway-session.target" ];
};
```

`PartOf` propagates stop/restart events from the parent to this unit, so the service is torn down when the compositor session ends.

## Service types

The same types available for system services apply here:

| Type | Use when |
|---|---|
| `simple` | Long-running daemon — process stays alive indefinitely |
| `oneshot` | Task that runs to completion and exits — scripts, polls, timer-driven tasks |
| `notify` | Long-running daemon that signals readiness via `sd_notify` |

## Timer-activated user service

Timers and services share the same name. The `Timer` section uses the same keys as system timers:

```nix
home-manager.users.${config.username} = {
  systemd.user.services.my-poller = {
    Unit = {
      Description = "Poll something";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${myScript}/bin/my-poller";
    };
  };

  systemd.user.timers.my-poller = {
    Unit = {
      Description = "Poll something every 2 minutes";
    };
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "2min";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
};
```

The service does **not** need `Install.WantedBy` — the timer activates it.

## D-Bus session bus

Services that send desktop notifications need access to the D-Bus session bus. Pass the socket address via an environment variable:

```nix
Service = {
  Type = "oneshot";
  ExecStart = "${myScript}/bin/my-script";
  Environment = "DBUS_SESSION_BUS_ADDRESS=%t/bus";
};
```

`%t` is a systemd specifier that expands to the user runtime directory (`/run/user/<uid>`).

## PATH in services

User services have a minimal PATH by default. Reference binaries by their full store path:

```nix
Service = {
  ExecStart = "${pkgs.curl}/bin/curl https://example.com";
};
```

## Rebuilds and service restarts

User services are restarted on `nixos-rebuild switch` by [sd-switch](https://github.com/oddlama/sd-switch), which compares the before/after unit state and restarts changed services in place — without requiring a re-login. This is enabled globally in this config.

Unlike system services, there is no `restartIfChanged` option for user services in Home Manager. sd-switch handles restart decisions automatically based on unit file changes.

## Checklist

When adding a new user service, verify each item before deploying:

**Type and scope**
- [ ] Service type chosen (`simple`, `oneshot`, `notify`)
- [ ] User vs [system service](system.md) decided — does it need root / boot-time start, or system secrets? Use a system service instead.

**Targets**
- [ ] `Install.WantedBy` set correctly for services that should start automatically (`default.target` or `graphical-session.target`)
- [ ] If the service needs a graphical session: `Unit.After = [ "graphical-session.target" ]` (or `sway-session.target`)
- [ ] If the service is compositor-specific and should stop with it: `Unit.PartOf = [ "sway-session.target" ]`
- [ ] Timer has `Install.WantedBy = [ "timers.target" ]`

**D-Bus**
- [ ] If the service sends desktop notifications: `Service.Environment = "DBUS_SESSION_BUS_ADDRESS=%t/bus"` is set

**Error handling**
- [ ] Scripts use `set -euo pipefail` (automatic with `pkgs.writeShellApplication`) so failures are never silently swallowed

**Runtime**
- [ ] Binaries referenced by full store path (`${pkgs.foo}/bin/foo`)

**Verification**
- [ ] `systemctl --user status <unit>` shows active after deploy
- [ ] `journalctl --user -u <unit>` shows no unexpected errors on first run

## Real examples in this codebase

| Module | Pattern |
|---|---|
| `modules/common/battery/` | Oneshot + timer + D-Bus notifications |
| `modules/common/repos/` | Oneshot + timer for per-repo git fetches |
| `modules/common/transcription/` | Long-running daemon scoped to `sway-session.target` with `PartOf` |
