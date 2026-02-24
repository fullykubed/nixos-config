# Remote Builders

Dynamic Hetzner Cloud builders for distributed NixOS builds, with an S3-backed binary cache.

## Overview

This system provisions NixOS remote builders on Hetzner Cloud on-demand when builds are initiated via SSH. Builders automatically delete themselves after 60 minutes of inactivity, keeping costs to a minimum. All build outputs are automatically signed and uploaded to a Cloudflare R2-backed binary cache so they can be reused across machines and future builds.

Key properties:

- On-demand: builders are created only when `nix` connects to them
- Ephemeral: fresh Nix store on each launch, no persistent state
- Self-managing: builders monitor inactivity and delete themselves via the Hetzner API
- Secret-managed: API tokens and SSH keys handled by agenix
- Two-tier: regular builders for small packages, big-parallel builders for heavy builds
- Cached: every build output is pushed to a persistent binary cache via [niks3](https://github.com/Mic92/niks3)

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           LOCAL WORKSTATION                                   │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────┐   ┌──────────────────┐   ┌─────────────────────────┐       │
│  │   un.sh     │──▶│ nix.buildMachines│──▶│  SSH ProxyCommand       │       │
│  │ -B N -P M   │   │ builder-1..N     │   │  hetzner-builder-proxy  │       │
│  │             │   │ big-builder-1..M │   └────────────┬────────────┘       │
│  └─────────────┘   └──────────────────┘           SSH (:3098)                │
│                                                         │                     │
│  ┌─────────────┐   ┌──────────────────┐                │                     │
│  │   Waybar    │◀──│ hcloud poll (30s)│                │                     │
│  │   Module    │   │ + upload queue   │                │                     │
│  └─────────────┘   └──────────────────┘                │                     │
│                                                         │                     │
│  ┌─────────────┐                                       │                     │
│  │  builders   │   CLI tools (hcloud API)              │                     │
│  │  cache      │                                       │                     │
│  └─────────────┘                                  SSH (:3099)                │
│                                                         │                     │
│  ┌─────────────────────────────────────────┐           │                     │
│  │ post-build-hook → pending/ queue        │           │                     │
│  │   ▼                                     │           │                     │
│  │ cache-upload.service ───────────────────┼───────────┼──┐                 │
│  │ (path unit + hourly timer)              │           │  │                 │
│  └─────────────────────────────────────────┘           │  │                 │
│                                                         │  │                 │
│  nix.substituters ── HTTPS ──────────────────────────────────────▶ CDN (R2) │
│                                                         │  │                 │
└─────────────────────────────────────────────────────────┼──┼─────────────────┘
                                                     :3098│  │:3099
                                                          ▼  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                          HETZNER CLOUD (hel1)                                │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │                    NixOS Builder Snapshot (shared)                    │    │
│  │  Built with make-disk-image, uploaded via upload-image.sh            │    │
│  │  Tier-agnostic: cloud-init writes overrides for big-parallel at boot │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                              │                                               │
│              ┌───────────────┼───────────────┐                              │
│              ▼               ▼               ▼                              │
│  ┌───────────────┐  ┌───────────────┐  ┌─────────────────┐                │
│  │  builder-1    │  │  builder-N    │  │ big-builder-1   │                │
│  │  cpx42        │  │  cpx42        │  │ ccx33           │                │
│  │  4 jobs       │  │  4 jobs       │  │ 1 job, all cores│                │
│  │ ┌───────────┐ │  │ ┌───────────┐ │  │ ┌───────────┐   │                │
│  │ │ nix-daemon│ │  │ │ nix-daemon│ │  │ │ nix-daemon│   │                │
│  │ └───────────┘ │  │ └───────────┘ │  │ └───────────┘   │                │
│  │ ┌───────────┐ │  │ ┌───────────┐ │  │ ┌───────────┐   │                │
│  │ │cache-     │ │  │ │cache-     │ │  │ │cache-     │   │                │
│  │ │upload ────┼─┤  │ │upload ────┼─┤  │ │upload ────┼───┤                │
│  │ └───────────┘ │  │ └───────────┘ │  │ └───────────┘   │                │
│  │ ┌───────────┐ │  │ ┌───────────┐ │  │ ┌───────────┐   │                │
│  │ │ inactivity│ │  │ │ inactivity│ │  │ │ inactivity│   │                │
│  │ │  monitor  │ │  │ │  monitor  │ │  │ │  monitor  │   │                │
│  │ └─────┬─────┘ │  │ └─────┬─────┘ │  │ └─────┬─────┘   │                │
│  └───────┼───────┘  └───────┼───────┘  └───────┼─────────┘                │
│          └──────────────────┴──────┬───────────┘                            │
│    inactivity: hcloud server delete (self) after 60 min                     │
│    cache-upload: SSH tunnel (:3099) ────┐                                   │
│                                          ▼                                   │
│  ┌──────────────────────────────────────────────┐                           │
│  │              CACHE SERVER (cache-1)           │                           │
│  │              cpx22 · persistent 24/7          │                           │
│  │                                               │                           │
│  │  ┌────────────┐   ┌──────────┐               │                           │
│  │  │ niks3      │──▶│PostgreSQL│               │                           │
│  │  │ :5751      │   └──────────┘               │                           │
│  │  │ (SSH only) │                              │                           │
│  │  └────────────┘                              │                           │
│  │  SSH :3099 (host key verified)               │                           │
│  └──────────────────────────────────────────────┘                           │
│                          │                                                   │
└──────────────────────────┼───────────────────────────────────────────────────┘
                           │ S3 API
                           ▼
                 ┌─────────────────┐
                 │  Cloudflare R2  │
                 │  S3 API (write) │
                 │  CDN (read)     │
                 └─────────────────┘
```

## Component Overview

1. **Builder Snapshot**: Pre-built NixOS image created with `nixpkgs make-disk-image` and uploaded to Hetzner as a snapshot. Contains the full builder configuration: Nix daemon, `remotebuild` user, cache upload queue, and inactivity monitor. The same snapshot is used for both regular and big-parallel builders. Defined in `builders/image.nix`.

2. **SSH ProxyCommand** (`modules/common/remote-builders/proxy-command.sh`): Intercepts SSH connections to `builder-N` and `big-builder-N` hosts. If the server does not exist, it provisions one from the snapshot via the Hetzner API, injects SSH keys via cloud-init, then waits for SSH to become available on port 3098 before proxying the connection.

3. **Nix buildMachines** (`modules/common/remote-builders/default.nix`): Static `nix.buildMachines` entries for `builder-1` through `builder-N` (regular) and `big-builder-1` through `big-builder-M` (big-parallel). SSH config routes each hostname through the ProxyCommand transparently.

4. **Inactivity Monitor** (`builders/inactivity-monitor.nix`): Systemd timer that runs every minute on each builder. Checks for active `nixbld` processes and SSH sessions. After 60 consecutive minutes of inactivity, calls `hcloud server delete` on itself.

5. **Waybar Module** (`modules/common/sway/waybar/waybar-builders.sh`): Polls `hcloud server list` every 30 seconds to display active builder count and cache status in the status bar. Shows `N+M` format (N regular + M big-parallel) when both types are active, plus upload queue depth.

6. **CLI Tools**: `builders` (`modules/common/remote-builders/builders-cli.sh`) for builder fleet management, `cache` (`modules/common/binary-cache/cache-cli.sh`) for cache server management.

7. **Cache Server** (`cache/image.nix`): Persistent Hetzner instance running niks3 backed by PostgreSQL, storing NARs in Cloudflare R2. Only accessible via SSH tunnel on port 3099.

8. **Binary Cache Module** (`modules/common/binary-cache/default.nix`): Client-side integration on local machines — SSH tunnel, upload queue, healthchecks, status polling, and secrets management.

## Sub-documents

See [TOC.md](TOC.md) for a listing of all documents in this directory.
