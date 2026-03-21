# Remote Builders

Ephemeral NixOS VMs on Hetzner Cloud that perform distributed compilation. Builders are provisioned on-demand when Nix connects to them and auto-destroy after 60 minutes of inactivity.

## Key Properties

- **On-demand**: Builders are created only when `nix` connects to them via SSH
- **Ephemeral**: Fresh Nix store on each launch, no persistent state
- **Self-managing**: Each builder monitors its own inactivity and deletes itself via the Hetzner API
- **Two-tier**: Regular builders for small packages, big-parallel builders for heavy builds (see [builder tiers](builders.md))
- **Shared image**: The same NixOS snapshot serves both tiers; croc transfers tier-specific settings at boot via the controller's relay

## Provisioning Flow

```
un.sh -B 3 -P 1
    │
    ▼
nix build → needs builder-1 → SSH connection
    │
    ▼
SSH Match exec (ensure-builder.sh)
    │
    ├── builder reachable? ──yes──▶ SSH connect ──▶ builder
    │
    └── no
         │
         ▼
    builders create builder-1
      - preflight: verify controller croc relay is reachable
      - mint ephemeral Headscale pre-auth key
      - generate one-time croc code
      - cloud-init user-data (minimal):
          • croc relay password → /run/croc-relay-password
          • croc transfer code → /run/croc-code
      - hcloud server create (from snapshot, label: type=builder)
      - croc send (blocks until builder receives):
          • install-secrets.sh containing all secrets:
            SSH keys, host keys, Hetzner token, Headscale auth key,
            niks3 token, R2 credentials, builder config
      - wait for Tailscale join
         │
         ▼
    wait for SSH port 3098 (~30-60 seconds)
         │
         ▼
    SSH connect ──▶ builder ready for builds
```

## Builder Image

The builder image is a NixOS disk image built with `nixpkgs make-disk-image` and uploaded to Hetzner as a snapshot. Defined in `images/builder/`.

| File | Purpose |
|---|---|
| `images/builder/default.nix` | Entry point (imports image.nix + hardware.nix) |
| `images/builder/image.nix` | Full builder config: SSH, cloud-init, nix daemon, cache upload, ccache |
| `images/builder/hardware.nix` | Hetzner Cloud hardware configuration |
| `images/builder/hardening.nix` | Kernel sysctl + boot param hardening |
| `images/builder/inactivity-monitor.nix` | Self-deletion timer |
| `images/builder/upload-image.sh` | Build and upload script |

### Builder Services

Each builder runs these services:

| Service | Purpose |
|---|---|
| `nix-daemon` | Accepts build jobs from the coordinator (memory-limited to 90%) |
| `sshd` | Port 3098, hardened ciphers (chacha20, sntrup761x25519, hmac-sha2-512-etm) |
| `cloud-init` | Writes croc bootstrap payload (relay password + transfer code) |
| `croc-receive` | Downloads and installs secrets via croc relay |
| `cache-tunnel` | SSH tunnel to niks3 cache (local:9751 → cache:5751 via SSH:3099) |
| `cache-upload` | Processes upload queue, batches 32 paths per niks3 push |
| `ccache-r2-mount` | s3fs FUSE mount of R2 bucket for shared compiler cache |
| `inactivity-monitor` | Checks every minute; self-deletes after 60 min idle |

### Nix Daemon Configuration

```
max-jobs = 4              # (regular) or 1 (big-parallel, via croc-transferred override)
cores = 4                 # (regular) or 0 (big-parallel, all cores for single job)
eval-cores = 3            # Parallel Nix evaluation
keep-going = true
max-silent-time = 1800    # 30 min timeout on silent builds
timeout = 21600           # 6 hour absolute timeout
allow-import-from-derivation = false
extra-experimental-features = nix-command flakes cgroups parallel-eval
use-cgroups = true
auto-optimise-store = true
post-build-hook = /etc/nix/enqueue-to-cache.sh
connect-timeout = 5       # Fail fast if substituters are slow
stalled-download-timeout = 15
extra-sandbox-paths = /var/cache/ccache /var/cache/ccache-r2?
```

The `!include /etc/nix/builder-override.conf` directive in `nix.extraOptions` loads the croc-transferred override for big-parallel builders. Regular builders get an empty file.

### Hardening

Builders are hardened beyond NixOS defaults (`images/builder/hardening.nix`):

- **Kernel sysctl**: 32+ parameters (ASLR, KASLR, restricted dmesg/ptrace/bpf, SYN cookies, ICMP hardening)
- **Boot params**: `slab_nomerge`, `init_on_alloc=1`, `init_on_free=1`, `page_alloc.shuffle=1`
- **Blacklisted modules**: Unused filesystems (cramfs, freevxfs, hfs, squashfs, udf) and protocols (dccp, sctp, rds, tipc)
- **Disabled features**: kexec, hibernation, coredumps
- **SSH**: chacha20-poly1305 cipher, sntrup761x25519 KEX, hmac-sha2-512-etm MAC, key-only auth

### Updating the Image

```bash
# Build and upload to Hetzner
./images/builder/upload-image.sh
```

Existing running builders continue with the old image. New builders automatically use the latest snapshot (resolved by label `type=builder` at provisioning time).

## Inactivity Monitor

A systemd timer that runs every minute on each builder:

1. Checks for active `nixbld` processes and SSH sessions
2. Increments a counter file if idle, resets to 0 if active
3. After 60 consecutive idle minutes, calls `hcloud server delete` on itself using the Hetzner API token from `/run/hcloud-token`

The server name is read from the Hetzner metadata endpoint (`169.254.169.254/hetzner/v1/metadata/hostname`).

## SSH Configuration

Builders run SSH on port **3098** with strict settings:

- Key-only authentication (no passwords)
- Agent forwarding disabled
- X11 forwarding disabled
- TCP forwarding limited to local
- 3 max auth tries, 30s login grace time

The client SSH config is generated by `modules/common/remote-builders/default.nix` with:
- `ProxyCommand` pointing to `proxy-command.sh`
- `HostKeyAlias` for host key verification
- Hardened cipher/KEX/MAC selection matching the server

## Firewall

Only port 3098 (SSH) is open. The cache tunnel uses an outbound SSH connection to the cache server on port 3099 — no inbound port is needed.

## Usage

### Rebuilding with Builders

```bash
# Rebuild using all configured builders (regular + big-parallel)
un.sh

# Use 3 regular builders + 1 big-parallel builder
un.sh -B 3 -P 1

# Use only regular builders (no big-parallel)
un.sh -B 3 -P 0

# Disable all remote builders for a local-only build
un.sh -B 0

# Skip binary cache lookups (faster when most packages need rebuilding)
un.sh -S

# Build in offline mode (no network)
un.sh -o

# Stop on first failure for debugging
un.sh -s

# Update flake inputs then rebuild
un.sh -u

# Rebuild boot config only (no live switch)
un.sh -b
```

The `-B`/`--builders` flag controls regular builder count and `-P`/`--big-builders` controls big-parallel builder count. When a builder is first contacted, the ProxyCommand provisions it on Hetzner if it does not already exist and waits for SSH to be ready (~30-60 seconds).

### Managing Builders

```bash
# List active builders with IP and status
builders list

# Show summary with estimated hourly cost (per-tier breakdown)
builders status

# Live-updating resource dashboard (CPU, memory, disk I/O, builds)
builders dashboard

# Check SSH connectivity, Nix, and network bandwidth
builders check builder-1
builders check big-builder-1

# Manually create a builder (without triggering a build)
builders create builder-1
builders create big-builder-1

# Destroy a specific builder
builders destroy builder-1
builders destroy big-builder-1

# Destroy all builders (prompts for confirmation)
builders destroy-all
```

### Waybar Status

The waybar module shows the active builder count with a server icon. When both regular and big-parallel builders are running, the display shows `N+M` (N regular + M big-parallel). Hovering over the icon displays each builder name and IP address, grouped by type. No builders shows nothing (idle state).
