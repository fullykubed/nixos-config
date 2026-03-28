# Compiler Cache

`modules/common/ccache/default.nix` backs the ccache compiler cache with Cloudflare R2 so compilation hits are shared across all machines — local workstations and remote builders alike.

## Architecture

ccache uses a three-tier storage hierarchy. On a cache miss, it checks each tier in order:

```
┌────────────────────────────────────────────────────────────┐
│  /var/cache/ccache          — Local cache (fastest)        │
│  Populated by every build, checked first                   │
├────────────────────────────────────────────────────────────┤
│  /var/cache/ccache-r2-upload — Local R2 write dir           │
│  New remote entries land here instantly                     │
│  s5cmd syncs to R2 every 60s, then deletes local copies    │
├────────────────────────────────────────────────────────────┤
│  /var/cache/ccache-r2-download — s5cmd sync'd copy (r/o)   │
│  Shared cache from all machines, synced from R2            │
└────────────────────────────────────────────────────────────┘
```

The `CCACHE_REMOTE_STORAGE` variable chains these:
```
file:///var/cache/ccache-r2-upload|umask=002|layout=subdirs
file:///var/cache/ccache-r2-download|read-only|umask=002|layout=subdirs
```

When ccache writes a new entry to remote storage, it goes to the first writable backend (`ccache-r2-upload`). The background upload service then pushes it to R2 where all machines can read it through the periodically-synced local copy.

### Why two components: a local staging directory _and_ a periodic download sync

ccache's `CCACHE_REMOTE_STORAGE` feature needs file-system-like paths — it reads and writes cache entries as regular files. Both the write path and the read path are optimised separately to avoid blocking builds.

The two-component design solves this:

- **`ccache-r2-upload`** (local staging directory) is a plain filesystem directory. ccache writes land instantly with zero network latency. The `ccache-r2-upload` timer picks up new files every 60 seconds and uploads them to R2 in parallel using s5cmd, then deletes the local copies. This decouples write latency from build speed.

- **`ccache-r2-download`** (local download sync) is read-only. The `ccache-r2-download` service uses s5cmd to sync the full R2 bucket to a local directory every 30 minutes. This avoids per-file network latency on cache reads: all lookups hit local disk, and the periodic bulk sync keeps the local copy fresh without adding any latency to individual builds. The `read-only` flag in `CCACHE_REMOTE_STORAGE` tells ccache to never attempt writes through this path. (This replaces an earlier s3fs FUSE mount approach, which added too much latency on cache misses — every miss required a network round-trip to R2, and the overhead across thousands of compilation units made the shared cache a net negative for build performance.)

The result: writes are instant (local filesystem), reads from the shared pool are fast (local disk after a periodic bulk sync), and the background services bridge the two without blocking builds.

## stdenv Integration

`modules/common/stdenv/default.nix` overrides the global stdenv to wrap every C/C++ compiler with ccache via a `preConfigure` hook. Each derivation gets:

1. ccache added as a `nativeBuildInput`
2. Environment variables pointing to local cache and R2 remote storage
3. A `preConfigure` hook that wraps `CC` and `CXX` with thin ccache wrapper scripts

### preConfigure Hook

The hook runs before each derivation's configure phase:

1. Checks that `CCACHE_DIR` exists and is writable
2. Skips if `CC`/`CXX` already point to a ccache wrapper (prevents infinite recursion)
3. Creates wrapper scripts in `/build/.ccache-wrap/` that invoke `ccache <original-compiler>` for compilation (`-c` flag present) and fall through to the original compiler for linking

The hook only activates when `preConfigure` is a string (or absent). Function-style `preConfigure` is passed through unchanged.

### Rust Builds

nixpkgs Rust build hooks (`cargo-build-hook.sh`, `cargo-check-hook.sh`) invoke cargo with inline environment variables like `CC_x86_64_unknown_linux_gnu=/nix/store/.../cc`. The Rust `cc` crate prefers these target-specific `CC_<target>` variables over the generic `CC`, so our ccache-wrapped `CC` is bypassed.

The preConfigure hook fixes this by placing a `cargo` wrapper script in `/build/.ccache-wrap/` (already on PATH). When cargo is invoked:

1. The wrapper discovers `CC_*`, `CXX_*`, `HOST_CC`, and `HOST_CXX` environment variables
2. For each one pointing to a real compiler (absolute path, not already wrapped), it creates a ccache wrapper script
3. It exports the overridden variables so the `cc` crate picks up the wrapped compilers
4. It execs the real cargo (saved as `CCACHE_REAL_CARGO` before PATH was modified)

The wrapper is only created when cargo is found on PATH (i.e., Rust builds). Non-Rust builds are unaffected. The wrapper creation is idempotent — if a wrapper already exists for a given variable, it is reused.

## Systemd Services

### `ccache-r2-download` — Periodic R2 Sync

Downloads the full R2 bucket to `/var/cache/ccache-r2-download` via s5cmd sync.

- **Type**: oneshot (triggered by timer)
- **Timer**: 30s after boot, then every 30 min
- **After**: `agenix.service`, `network-online.target`
- **Restart**: on-failure, 5min delay
- **Credentials**: Reads `ccache-r2-access-key` and `ccache-r2-secret-key` from agenix
- **Command**: `s5cmd sync` — downloads all objects from the R2 bucket to the local directory in parallel

On builders, the service waits for secrets-ready.target (croc transfer) to deliver R2 credentials before syncing. On local machines, credentials come from agenix at activation.

### `ccache-r2-upload` — Background Upload

Pushes new cache entries from `/var/cache/ccache-r2-upload` to R2 via s5cmd.

- **Type**: oneshot (triggered by timer)
- **Timer**: 30s after boot, then every 60s
- **Restart**: on-failure, 5min delay
- **Process**: Finds all files in local dir, generates s5cmd batch commands, uploads in parallel, deletes uploaded files, cleans empty subdirs

### Local vs Builder Differences

Local machines and remote builders run the same services (`ccache-r2-download`, `ccache-r2-upload`) with the same s5cmd sync approach. The only differences are operational:

| Aspect | Local machines | Remote builders |
|---|---|---|
| Credential source | agenix (`/run/agenix/ccache-r2-*`) | croc transfer (`/run/ccache-r2-*`) |
| Service dependency | `after = agenix.service` | `requires = secrets-ready.target` |

## Filesystem Layout

```
/var/cache/
├── ccache/              # Primary local cache (CCACHE_DIR)
│                        #   Permissions: 0775 root:nixbld
│                        #   Used by: all builds (sandbox-mounted)
├── ccache-r2-upload/     # Staging dir for R2 uploads
│                        #   Permissions: 0775 root:nixbld
│                        #   Used by: ccache remote_storage writes
│                        #   Synced to R2 every 60s by ccache-r2-upload
└── ccache-r2-download/  # s5cmd sync'd copy (read-only shared cache)
                         #   Permissions: 0775 root:nixbld
                         #   Populated by: ccache-r2-download service
```

All directories are created by `systemd.tmpfiles.rules` with `0775 root:nixbld` permissions so the nix build sandbox can read and write to them.

## Sandbox Integration

The directories are exposed into Nix build sandboxes via `extra-sandbox-paths`:

```nix
extra-sandbox-paths = [
  "/var/cache/ccache"          # Always present
  "/var/cache/ccache-r2-upload?"  # Optional (? = graceful if missing)
  "/var/cache/ccache-r2-download?"  # Optional (? = graceful if missing)
];
```

The `?` suffix is critical — it lets builds proceed even if the download sync hasn't completed yet (e.g., during early boot or on machines without R2 credentials).

## R2 Backend

| Property | Value |
|---|---|
| Bucket | `ccache` |
| Endpoint | `https://f875b3b102f2a88a51db200ba95e1fc9.r2.cloudflarestorage.com` |
| Upload tool | s5cmd (parallel S3 client) |
| Download tool | s5cmd sync (parallel S3 sync) |
| Layout | `subdirs` (ccache directory-based layout) |

## Secrets

| Secret | Path | Purpose |
|---|---|---|
| `ccache-r2-access-key` | `/run/agenix/ccache-r2-access-key` | Cloudflare R2 access key |
| `ccache-r2-secret-key` | `/run/agenix/ccache-r2-secret-key` | Cloudflare R2 secret key |

Both secrets are agenix-managed with `mode = "0400"` (root-only read). The s5cmd download and upload services read them at service start.

## Troubleshooting

### ccache not activating in builds

1. Check that the ccache directory exists and is writable by nixbld:
   ```bash
   ls -la /var/cache/ccache
   ```
   Should be `drwxrwxr-x root nixbld`.

2. Check that it's in the sandbox paths:
   ```bash
   nix show-config | grep extra-sandbox-paths
   ```

3. Check build logs for the ccache hook output — it prints diagnostics when the directory is missing or unwritable.

### R2 download sync fails

1. Check credentials:
   ```bash
   cat /run/agenix/ccache-r2-access-key
   ```
2. Check service logs:
   ```bash
   journalctl -u ccache-r2-download
   ```
3. Verify network connectivity to R2:
   ```bash
   curl -I https://f875b3b102f2a88a51db200ba95e1fc9.r2.cloudflarestorage.com
   ```
4. Run the download manually:
   ```bash
   systemctl start ccache-r2-download
   journalctl -u ccache-r2-download -n 20
   ```
5. Check the timer status:
   ```bash
   systemctl status ccache-r2-download.timer
   ```

### Sync not uploading

1. Check timer status:
   ```bash
   systemctl status ccache-r2-upload.timer
   ```
2. Run sync manually:
   ```bash
   systemctl start ccache-r2-upload
   journalctl -u ccache-r2-upload -n 20
   ```
3. Check for files stuck in the local dir:
   ```bash
   find /var/cache/ccache-r2-upload -type f | head
   ```
