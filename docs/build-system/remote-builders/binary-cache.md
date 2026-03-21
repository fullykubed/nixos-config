# Binary Cache

Every build output — whether from the local machine or a remote builder — is automatically signed and uploaded to a Cloudflare R2-backed binary cache using [niks3](https://github.com/Mic92/niks3). Subsequent builds on any machine can substitute from the cache instead of rebuilding.

## How It Works

**Writes** (build output → R2):

1. Nix build completes (local or on a builder)
2. Post-build-hook enqueues the store path to `/var/lib/cache-upload-queue/pending/`
3. `cache-upload.service` batches 32 paths and calls `niks3 push` through an SSH tunnel
4. niks3 signs the NAR and uploads it to R2 via S3 API

**Reads** (nix substituter → R2):

1. Nix checks `extra-substituters` before building a derivation
2. HTTPS request to Cloudflare CDN custom domain serves from R2
3. Client verifies the narinfo signature against `trusted-public-keys`

## Upload Queue

The upload queue lives at `/var/lib/cache-upload-queue/` on both local machines and builders:

```
/var/lib/cache-upload-queue/
├── pending/       # One file per store path (filename = nix hash, content = full path)
└── done/          # Empty marker files for deduplication (pruned weekly)
```

Three systemd units cooperate to process it:

| Unit | Type | Purpose |
|---|---|---|
| `cache-upload.path` | Path | Triggers upload immediately when new items appear in `pending/` |
| `cache-upload.timer` | Timer | Retries hourly (and 5 min after boot) to catch anything missed |
| `cache-upload.service` | Oneshot | Batches and uploads paths via `niks3 push` |

On failure, the service retries after 5 minutes (`Restart=on-failure`). There is no start rate limit — the path unit triggers frequently during active builds and that is expected.

A weekly prune timer (`cache-upload-prune.service`) clears the `done/` markers and re-enqueues the entire current system closure to keep all packages cached.

## Cache Server

The cache server is a persistent Hetzner instance (not ephemeral like builders). It runs niks3 with a PostgreSQL backend, storing NARs in Cloudflare R2.

| Property | Value |
|---|---|
| Server type | cpx22 (2 vCPU, 4 GB RAM) |
| Location | hel1 (Helsinki) |
| niks3 | Listens on 127.0.0.1:5751 (not exposed publicly) |
| SSH | Port 3099 (only open port) |
| Storage | Cloudflare R2 bucket (zero egress via CDN) |
| Config | `images/cache/image.nix` |

The niks3 write API is only reachable via SSH tunnel — the firewall exposes nothing except SSH. Both local machines and builders establish a tunnel:

```
local:9751  ──SSH (:3099)──▶  cache:5751 (niks3)
```

The `cache-tunnel.service` discovers the cache server IP via `hcloud server list -l cache=true`, establishes the tunnel, and writes `/run/niks3-server-url` when ready. A healthcheck polls every 30 seconds and disables uploads after 3 consecutive failures.

## Managing the Cache

```bash
# Show cache server status, IP, uptime
cache status

# Create the cache server from latest snapshot
cache create

# Check SSH, niks3 health, PostgreSQL, disk space
cache check

# Destroy cache server (R2 data persists)
cache destroy

# Manually enqueue all paths in the current system closure
cache enqueue all
```

## Cache Secrets

All managed with agenix, rekeyed per machine:

| Secret | Path | Purpose |
|---|---|---|
| `cache-ssh-key` | `/root/.ssh/cache-key` | SSH key for tunnel access |
| `cache-host-key.pub` | `/etc/ssh/cache-host-key.pub` | Server host public key (all clients) |
| `cache-signing-key` | `/run/agenix/cache-signing-key` | Ed25519 NAR signing key |
| `niks3-api-token` | `/run/agenix/niks3-api-token` | Bearer token for `niks3 push` |
| `r2-access-key` | `/run/agenix/r2-access-key` | Cloudflare R2 access key |
| `r2-secret-key` | `/run/agenix/r2-secret-key` | Cloudflare R2 secret key |

On the controller, these are transferred via croc at boot into `/run/niks3-secrets/`. Only a relay password and one-time transfer code pass through cloud-init.

## Cache Setup

If setting up the cache for the first time (builder setup is covered in [setup.md](setup.md)):

1. Generate cache SSH key pair, host key pair, and NAR signing key (see `docs/secrets.md`)
2. Create a Cloudflare R2 bucket and store the credentials as agenix secrets
3. Add the R2 custom domain and signing public key to `flake.nix` `cacheModule`
4. Build and upload the cache image: `./images/cache/upload-image.sh`
5. Create the server: `cache create`
6. Rebuild the local system to deploy the cache module: `un.sh`

## Updating the Cache Server Image

Similar to builders:

1. Edit `images/cache/image.nix`
2. Build and upload: `./images/cache/upload-image.sh`
3. Destroy and recreate: `cache destroy && cache create`

R2 data persists across server destruction — only the niks3 process and PostgreSQL reference database are lost. The database is rebuilt automatically as new pushes arrive.
