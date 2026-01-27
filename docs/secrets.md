# Secret Management

This configuration uses [agenix](https://github.com/ryantm/agenix) for managing encrypted secrets with per-machine rekeying.

## How It Works

1. Secrets are stored encrypted in `secrets/`
2. Each machine has its own public key in `yubikeys/`
3. Secrets are automatically rekeyed for each machine
4. Decrypted at runtime into `/run/agenix/`

## Adding a New Secret

```bash
# Create and edit secret
agenix -e secrets/new-secret.age

# Rekey for all machines
nix run .#agenix-rekey
```

## Directory Structure

```
secrets/
├── *.age              # Age-encrypted secret files
└── rekeyed/           # Per-machine encrypted secrets
    ├── fullykubed-tower/
    └── fullykubed-mini-pc/

yubikeys/
├── yubikey_a_identity.pub
└── yubikey_b_identity.pub
```

## Resources

- [Agenix Documentation](https://github.com/ryantm/agenix)
- [agenix-rekey](https://github.com/oddlama/agenix-rekey)
