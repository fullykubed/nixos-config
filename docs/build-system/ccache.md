# Compiler Cache

`modules/common/ccache/default.nix` backs the ccache compiler cache with Cloudflare R2 so compilation hits are shared across all machines — local workstations and remote builders alike.

## Architecture

ccache uses a three-tier storage hierarchy. On a cache miss, it checks each tier in order:

```
┌────────────────────────────────────────────────────────────┐
│  /var/cache/ccache          — Local cache (fastest)        │
│  Populated by every build, checked first                   │
├────────────────────────────────────────────────────────────┤
│  /var/cache/ccache-r2-local — Local R2 write dir           │
│  New remote entries land here instantly                     │
│  s5cmd syncs to R2 every 60s, then deletes local copies    │
├────────────────────────────────────────────────────────────┤
│  /var/cache/ccache-r2       — s3fs FUSE mount (read-only)  │
│  Shared cache from all machines, mounted from R2           │
└────────────────────────────────────────────────────────────┘
```

The `CCACHE_REMOTE_STORAGE` variable chains these:
```
file:///var/cache/ccache-r2-local|umask=002|layout=subdirs
file:///var/cache/ccache-r2|read-only|umask=002|layout=subdirs
```

When ccache writes a new entry to remote storage, it goes to the first writable backend (`ccache-r2-local`). The background sync service then uploads it to R2 where all machines can read it through the s3fs mount.

### Why two components: s3fs mount _and_ a local staging directory

ccache's `CCACHE_REMOTE_STORAGE` feature needs file-system-like paths — it reads and writes cache entries as regular files. A single read-write s3fs mount would seem like the obvious choice, but s3fs writes are slow: each `write()` + `close()` triggers a full S3 PUT of the entire object, and s3fs serialises metadata operations. During a large build, hundreds of new cache entries would bottleneck on sequential S3 uploads inline with the compiler, adding latency to every compilation.

The two-component design solves this:

- **`ccache-r2-local`** (local staging directory) is a plain filesystem directory. ccache writes land instantly with zero network latency. The `ccache-r2-sync` timer picks up new files every 60 seconds and uploads them to R2 in parallel using s5cmd, then deletes the local copies. This decouples write latency from build speed.

- **`ccache-r2`** (s3fs FUSE mount) is read-only. It serves as a shared read path so every machine can look up cache entries written by other machines. Since it only handles reads (and s3fs stat caching keeps metadata lookups fast), the latency penalty is minimal — a remote-storage cache miss just adds one fast `stat()` call. The `read-only` flag in `CCACHE_REMOTE_STORAGE` tells ccache to never attempt writes through this path.

The result: writes are instant (local filesystem), reads from the shared pool are fast (s3fs with a 2M-entry stat cache), and the background sync bridges the two without blocking builds.

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

## Systemd Services

### `ccache-r2-mount` — s3fs FUSE Mount

Mounts the R2 bucket as `/var/cache/ccache-r2` read-only via s3fs-fuse.

- **After**: `agenix.service`, `network-online.target`
- **Restart**: on-failure, 10s delay
- **Credentials**: Reads `ccache-r2-access-key` and `ccache-r2-secret-key` from agenix, writes to `/run/s3fs-credentials`
- **Mount options**: `allow_other`, `umask=0002`, `gid=nixbld`, `complement_stat`, 2M stat cache entries, `listobjectsv2`, 5s connect timeout, 60s read/write timeout

On builders, the service waits for cloud-init to write R2 credentials before mounting. On local machines, credentials come from agenix at activation.

### `ccache-r2-sync` — Background Upload

Pushes new cache entries from `/var/cache/ccache-r2-local` to R2 via s5cmd.

- **Type**: oneshot (triggered by timer)
- **Timer**: 30s after boot, then every 60s
- **Restart**: on-failure, 5min delay
- **Process**: Finds all files in local dir, generates s5cmd batch commands, uploads in parallel, deletes uploaded files, cleans empty subdirs

### Local vs Builder Differences

Local machines and remote builders run the same services (`ccache-r2-mount`, `ccache-r2-sync`) with the same s3fs mount options. The only differences are operational:

| Aspect | Local machines | Remote builders |
|---|---|---|
| Credential source | agenix (`/run/agenix/ccache-r2-*`) | cloud-init (`/run/ccache-r2-*`) |
| Service activation | `wantedBy = multi-user.target` | Started by cloud-init `runcmd` |

## Filesystem Layout

```
/var/cache/
├── ccache/              # Primary local cache (CCACHE_DIR)
│                        #   Permissions: 0775 root:nixbld
│                        #   Used by: all builds (sandbox-mounted)
├── ccache-r2-local/     # Staging dir for R2 uploads
│                        #   Permissions: 0775 root:nixbld
│                        #   Used by: ccache remote_storage writes
│                        #   Synced to R2 every 60s by ccache-r2-sync
└── ccache-r2/           # s3fs FUSE mount (read-only shared cache)
                         #   Permissions: 0775 root:nixbld
                         #   Mounted by: ccache-r2-mount service
```

All directories are created by `systemd.tmpfiles.rules` with `0775 root:nixbld` permissions so the nix build sandbox can read and write to them.

## Sandbox Integration

The directories are exposed into Nix build sandboxes via `extra-sandbox-paths`:

```nix
extra-sandbox-paths = [
  "/var/cache/ccache"          # Always present
  "/var/cache/ccache-r2-local?"  # Optional (? = graceful if missing)
  "/var/cache/ccache-r2?"        # Optional (? = graceful if missing)
];
```

The `?` suffix is critical — it lets builds proceed even if the s3fs mount isn't ready yet (e.g., during early boot or on machines without R2 credentials).

## R2 Backend

| Property | Value |
|---|---|
| Bucket | `ccache` |
| Endpoint | `https://f875b3b102f2a88a51db200ba95e1fc9.r2.cloudflarestorage.com` |
| Upload tool | s5cmd (parallel S3 client) |
| Mount tool | s3fs-fuse |
| Layout | `subdirs` (ccache directory-based layout) |

## Secrets

| Secret | Path | Purpose |
|---|---|---|
| `ccache-r2-access-key` | `/run/agenix/ccache-r2-access-key` | Cloudflare R2 access key |
| `ccache-r2-secret-key` | `/run/agenix/ccache-r2-secret-key` | Cloudflare R2 secret key |

Both secrets are agenix-managed with `mode = "0400"` (root-only read). The s3fs mount and s5cmd sync read them at service start.

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

### R2 mount fails

1. Check credentials:
   ```bash
   cat /run/agenix/ccache-r2-access-key
   ```
2. Check service logs:
   ```bash
   journalctl -u ccache-r2-mount
   ```
3. Verify network connectivity to R2:
   ```bash
   curl -I https://f875b3b102f2a88a51db200ba95e1fc9.r2.cloudflarestorage.com
   ```

### Sync not uploading

1. Check timer status:
   ```bash
   systemctl status ccache-r2-sync.timer
   ```
2. Run sync manually:
   ```bash
   systemctl start ccache-r2-sync
   journalctl -u ccache-r2-sync -n 20
   ```
3. Check for files stuck in the local dir:
   ```bash
   find /var/cache/ccache-r2-local -type f | head
   ```
