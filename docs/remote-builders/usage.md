# Usage

## Building with Remote Builders

```bash
# Rebuild using all configured builders (regular + big-parallel)
un.sh

# Use 3 regular builders + 1 big-parallel builder
un.sh -B 3 -P 1

# Use only regular builders (no big-parallel)
un.sh -B 3 -P 0

# Disable all remote builders for a local-only build
un.sh -B 0
```

The `-B`/`--builders` flag controls regular builder count and `-P`/`--big-builders` controls big-parallel builder count. When a builder is first contacted, the ProxyCommand provisions it on Hetzner if it does not already exist and waits for SSH to be ready (~30-60 seconds).

## Managing Builders Manually

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

## Waybar Status

The waybar module shows the active builder count with a server icon. When both regular and big-parallel builders are running, the display shows `N+M` (N regular + M big-parallel). Hovering over the icon displays each builder name and IP address, grouped by type. No builders shows nothing (idle state).
