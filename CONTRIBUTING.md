# Contributing

## Development Environment

This project uses [direnv](https://direnv.net/) for automatic environment loading. When you `cd` into the repository, the development environment is automatically activated.

### What you get

- `nixfmt` for formatting
- `agenix-rekey` for secret management
- `gitleaks` for security scanning
- Pre-commit hooks configured

### Manual activation

If you don't have direnv, you can manually enter the development shell:

```bash
nix develop
```

## Testing Changes

Before deploying, verify your configuration builds successfully:

```bash
# Build configuration without deploying (no root required)
nix build .#nixosConfigurations.fullykubed-tower.config.system.build.toplevel
nix build .#nixosConfigurations.fullykubed-mini-pc.config.system.build.toplevel

# Run flake checks
nix flake check
```

Pre-commit hooks automatically run on commit to catch issues:
- `nixfmt` - Nix formatting
- `statix` - Nix linting
- `deadnix` - Dead code detection
- `gitleaks` - Secret leak detection

## Commands

```bash
# Format all Nix files
nix fmt

# Rekey secrets after modification
nix run .#agenix-rekey
```
