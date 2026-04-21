# Systemd Services

Systemd runs two separate service manager instances: a system instance (PID 1, runs as root) and a per-user instance (started on first login, runs as the user).

| | System service | User service |
|---|---|---|
| **NixOS option** | `systemd.services.*` | `home-manager.users.${user}.systemd.user.services.*` |
| **Runs as** | root or a dedicated system user | the logged-in user |
| **Starts** | at boot, before any login | when the user logs in |
| **Has access to** | `/etc`, `/var`, system sockets, secrets at `/run/agenix/` | `$HOME`, `$XDG_*`, D-Bus session bus, Wayland/X11 display |
| **Managed with** | `systemctl` | `systemctl --user` |
| **Logs** | `journalctl -u <unit>` | `journalctl --user -u <unit>` |

Use a **system service** when the service:
- Needs to run before or without a user session (boot-time setup, daemons, network services)
- Requires root or a dedicated system account (e.g. writing to `/var/lib/`, binding privileged ports)
- Reads secrets from `/run/agenix/`

Use a **user service** when the service:
- Needs to send desktop notifications (D-Bus session bus)
- Interacts with the Wayland compositor or X11 display (`$WAYLAND_DISPLAY`, `$DISPLAY`)
- Should only run while the user is logged in (battery monitor, auto-fetch, screen idle)
- Accesses user-owned files under `$HOME` or `$XDG_*` paths

For implementation details, see:
- [System services](system.md) — service types, timers, ordering targets, network/DNS readiness, secrets
- [User services](user.md) — Home Manager syntax, session targets, D-Bus, sd-switch

