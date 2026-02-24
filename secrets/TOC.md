# Table of Contents — secrets/

- **builder-host-key.age / .pub** - SSH host key pair for remote builder VMs, with the private key encrypted via agenix.
- **builder-ssh-key.age / .pub** - SSH authentication key pair for connecting to remote builder VMs.
- **cache-host-key.age / .pub** - SSH host key pair for the binary cache server.
- **cache-signing-key.age / .pub** - Nix binary cache signing key used to verify cached build artifacts.
- **cache-ssh-key.age / .pub** - SSH authentication key pair for connecting to the cache server.
- **exa-token.age** - Encrypted API token for the Exa search service used by Claude Code.
- **hetzner-api-token.age** - Encrypted Hetzner Cloud API token for provisioning builder and cache servers.
- **niks3-api-token.age** - Encrypted API token for the niks3 binary cache service.
- **pushover-token.age** - Encrypted Pushover notification service credentials for system alerts.
- **r2-access-key.age / r2-secret-key.age** - Encrypted Cloudflare R2 S3-compatible storage credentials for the binary cache.
- **rekeyed/** - Per-machine rekeyed secrets organized by hostname, containing machine-specific decryption variants of the master secrets.
