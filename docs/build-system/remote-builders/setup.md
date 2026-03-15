# Initial Setup

## 1. Create Hetzner Cloud Account

1. Sign up at https://console.hetzner.cloud
2. Create a new project for builders
3. Generate an API token with read/write permissions

## 2. Configure Secrets

```bash
# Store Hetzner API token
agenix -e secrets/hetzner-api-token.age
# Enter your API token when prompted

# Generate builder SSH key
ssh-keygen -t ed25519 -f /tmp/builder-key -N ""
agenix -e secrets/builder-ssh-key.age < /tmp/builder-key
cp /tmp/builder-key.pub secrets/builder-ssh-key.pub
rm /tmp/builder-key /tmp/builder-key.pub

# Generate builder host key (for SSH host verification)
ssh-keygen -t ed25519 -f /tmp/builder-host-key -N ""
agenix -e secrets/builder-host-key.age < /tmp/builder-host-key
cp /tmp/builder-host-key.pub secrets/builder-host-key.pub
rm /tmp/builder-host-key /tmp/builder-host-key.pub

# Rekey secrets for all machines
nix run .#agenix-rekey
```

For cache secrets (SSH keys, signing key, R2 credentials), see [Cache Setup](binary-cache.md#cache-setup).

## 3. Rebuild to Deploy Secrets

```bash
un.sh
```

This deploys the agenix secrets and SSH config to your system.

## 4. Build and Upload the Builder Image

```bash
# Build and upload to Hetzner (the script builds the image automatically)
./builders/upload-image.sh
```

The upload script builds the NixOS disk image via `nix build .#builder-image`, then uploads it to Hetzner as a snapshot labeled `type=builder`. The snapshot is resolved automatically at runtime — no manual snapshot ID configuration is needed.
