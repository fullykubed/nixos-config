# Build System

Distributed build infrastructure for NixOS: a hardened custom stdenv, shared compiler cache, ephemeral remote builders on Hetzner Cloud, and an S3-backed binary cache.

## Layers

The build system has four layers, each building on the last. Content-addressed derivations (CAS) are a cross-cutting concern that affects all layers:

```
┌────────────────────────────────────────────────────────────────────┐
│  Content-Addressed Derivations (cross-cutting)                      │
│  ca-derivations + contentAddressedByDefault — early cutoff          │
├────────────────────────────────────────────────────────────────────┤
│  4. Binary Cache                                                    │
│     niks3 + Cloudflare R2 — stores and serves build output (+ CA)  │
├────────────────────────────────────────────────────────────────────┤
│  3. Remote Builders                                                 │
│     Ephemeral Hetzner Cloud VMs — distributed compilation           │
├────────────────────────────────────────────────────────────────────┤
│  2. Compiler Cache (ccache)                                         │
│     R2-backed ccache — skip recompilation across machines           │
├────────────────────────────────────────────────────────────────────┤
│  1. Custom stdenv                                                   │
│     mold linker + hardening flags + ccache wrapping                 │
└────────────────────────────────────────────────────────────────────┘
```

**Layer 1** ([stdenv](stdenv.md)) overrides every package's build environment: the mold linker replaces GNU ld for faster linking, additional hardening flags are enabled globally, and every C/C++ compilation is wrapped with ccache. This is the foundation — it runs on local machines and remote builders alike.

**Layer 2** ([ccache](ccache.md)) backs the compiler cache with Cloudflare R2 so cache hits are shared across all machines. New compilations write to a local directory that syncs to R2 every 60 seconds; an s3fs FUSE mount provides read-only access to the full shared cache.

**Layer 3** ([remote builders](remote-builders/README.md)) provisions ephemeral NixOS VMs on Hetzner Cloud on-demand when `nix` initiates a build. They auto-destroy after 60 minutes idle. Two tiers — regular and big-parallel — route heavy derivations to appropriately-sized machines.

**Layer 4** ([binary cache](remote-builders/binary-cache.md)) stores every build output (NAR) in Cloudflare R2 via niks3. Both local machines and remote builders push to the cache through an SSH tunnel. Reads go through Cloudflare CDN with signature verification.

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
│  ┌─────────────────────────────────────────────┐       │  │                 │
│  │  Custom stdenv (mold + ccache + hardening)  │       │  │                 │
│  │  ccache-r2-mount (s3fs → R2, read-only)     │       │  │                 │
│  │  ccache-r2-sync  (s5cmd → R2, every 60s)    │       │  │                 │
│  └─────────────────────────────────────────────┘       │  │                 │
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
│  │  Custom stdenv (mold + ccache + hardening) baked into image          │    │
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
│  │ │ ccache-r2 │ │  │ │ ccache-r2 │ │  │ │ ccache-r2 │   │                │
│  │ │ (s3fs)    │ │  │ │ (s3fs)    │ │  │ │ (s3fs)    │   │                │
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

## Components at a Glance

| Component | What it does | Config |
|---|---|---|
| **Custom stdenv** | Overrides mkDerivation for all packages: mold linker, ccache wrapping, hardening flags | `modules/common/stdenv/default.nix` |
| **CAS module** | Enables ca-derivations and contentAddressedByDefault globally | `modules/utility/cas-module.nix` |
| **ccache module** | R2-backed compiler cache: s3fs mount, s5cmd sync, sandbox paths | `modules/common/ccache/default.nix` |
| **SSH ProxyCommand** | Intercepts SSH to `builder-N`, provisions Hetzner VM if absent | `modules/common/remote-builders/proxy-command.sh` |
| **Builder image** | Pre-built NixOS snapshot: nix-daemon, ccache, cache upload, inactivity monitor | `images/builder/image.nix` |
| **Inactivity monitor** | Per-builder timer; self-deletes via Hetzner API after 60 min idle | `images/builder/inactivity-monitor.nix` |
| **Binary cache module** | Client-side: SSH tunnel to niks3, upload queue, healthchecks | `modules/common/binary-cache/default.nix` |
| **Cache server image** | Persistent Hetzner VM running niks3 + PostgreSQL | `images/cache/image.nix` |
| **`builders` CLI** | Fleet management: list, status, dashboard, check, create, destroy | `modules/common/remote-builders/builders-cli.sh` |
| **`cache` CLI** | Cache server management: status, create, check, destroy, enqueue | `modules/common/binary-cache/cache-cli.sh` |
| **`un.sh`** | NixOS rebuild script with builder flags and nom integration | `modules/common/scripts/scripts/un.sh` |
| **Waybar module** | Status bar: active builder count, upload queue depth | `modules/common/sway/waybar/waybar-builders.sh` |

## How a Build Flows

1. User runs `un.sh -B 3 -P 1`
2. Nix evaluates the system configuration (custom stdenv applies mold, ccache, and hardening to every derivation)
3. Nix checks substituters for CA realisations (`.doi` files) — upstream caches don't serve these, so our niks3 cache is the primary source. If a realisation exists, Nix uses the cached output.
4. For uncached derivations, Nix schedules builds across local + remote builders
5. SSH ProxyCommand provisions any missing builders from the Hetzner snapshot (~30-60s)
6. Each builder's nix-daemon runs the build inside a sandbox with ccache directories mounted
7. ccache checks its local cache, then the R2-backed remote storage for compilation hits
8. On build completion, the post-build-hook enqueues the output to the upload queue
9. `cache-upload.service` batches 32 paths and pushes them to niks3 via SSH tunnel
10. niks3 signs the NAR and uploads to R2; Cloudflare CDN serves it for future reads
11. Early cutoff: if a rebuilt dependency produces identical content to its previous CA output, downstream dependents skip rebuilding
12. After 60 minutes with no active builds, the inactivity monitor deletes the builder

## Secrets

All secrets are managed with agenix + agenix-rekey (YubiKey-secured), decrypted at activation to `/run/agenix/`. On builders and the cache server, cloud-init injects them at boot.

| Secret | Used by | Purpose |
|---|---|---|
| `hetzner-api-token` | ProxyCommand, builders CLI, inactivity monitor | Hetzner Cloud API access |
| `builder-ssh-key` | Local SSH config | Key for builder SSH connections |
| `builder-host-key` | Local SSH config, cloud-init | Builder host key verification |
| `cache-ssh-key` | Cache tunnel | SSH key for tunnel to niks3 |
| `cache-host-key.pub` | Cache tunnel | Cache server host key verification |
| `cache-signing-key` | niks3 | Ed25519 NAR signing key |
| `niks3-api-token` | Upload service | Bearer token for niks3 push API |
| `r2-access-key` / `r2-secret-key` | niks3, cache server | Cloudflare R2 credentials (binary cache) |
| `ccache-r2-access-key` / `ccache-r2-secret-key` | ccache module, builder cloud-init | Cloudflare R2 credentials (compiler cache) |

## Further Reading

- [Custom stdenv](stdenv.md) — mold linker, hardening flags, ccache wrapping, package exclusions
- [Compiler cache](ccache.md) — R2-backed ccache architecture, sync services, sandbox integration
- [Remote builders](remote-builders/) — ephemeral Hetzner Cloud VMs, provisioning, binary cache, troubleshooting
