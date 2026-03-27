# Builder Tiers & Configuration

Builders are split into two tiers to route heavy derivations (Chromium, LLVM, Rust) to appropriately-sized machines while keeping small builds efficient and cheap.

## Tiers

| Property | Regular (`builder-N`) | Big-Parallel (`big-builder-N`) |
|---|---|---|
| Server type | cpx42 (8 shared vCPU, 16 GB) | ccx33 (8 dedicated vCPU, 32 GB) |
| maxJobs (client) | 4 | 1 |
| cores (builder) | 4 | 0 (all available) |
| RAM/job | 4 GB | 32 GB (single job) |
| mandatoryFeatures | (none) | big-parallel |
| supportedFeatures | nixos-test, kvm, benchmark | nixos-test, big-parallel, kvm, benchmark |

## How Scheduling Works

- Regular builders omit `big-parallel` from `supportedFeatures`, so derivations requiring `big-parallel` cannot be scheduled on them.
- Big-parallel builders set `mandatoryFeatures = ["big-parallel"]`, ensuring they ONLY accept derivations that require `big-parallel`. This prevents small packages from consuming expensive dedicated resources.
- Both tiers use the same Hetzner snapshot image. Cloud-init differentiates at boot: big-parallel builders write a nix override conf (`max-jobs = 1`, `cores = 0`) and restart the nix-daemon.

## Costs

Costs vary by builder tier:

| Tier | Server Type | Approx. Hourly Cost |
|---|---|---|
| Regular | cpx42 | ~0.0268/hr |
| Big-parallel | ccx33 | ~0.0950/hr |

Builders auto-destroy after 60 minutes of inactivity. The `builders status` command shows a per-tier cost breakdown. Check current Hetzner Cloud pricing for the latest rates.

## Updating the Builder Image

When you change the builder configuration (e.g., add packages to `images/builder/image.nix`):

1. Edit `images/builder/image.nix`
2. Build and upload: `./images/builder/upload-image.sh`
3. Existing running builders continue with the old image; new builders automatically use the latest snapshot

Note: The same snapshot is used for both regular and big-parallel builders. Cloud-init configures tier-specific settings at boot time.
