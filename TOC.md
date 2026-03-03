# Table of Contents

## Files

- **flake.nix** - Main Nix flake defining inputs, overlays, system configurations for two machines (tower and mini-pc), and build outputs for builder/cache disk images.
- **configuration.nix** - Base NixOS system configuration that imports 60+ shared modules covering boot, networking, security, desktop, development tools, and multimedia.
- **README.md** - Project overview documenting the multi-machine NixOS setup with emphasis on declarative configuration, modular composition, and security features.
- **CONTRIBUTING.md** - Development guidelines covering the direnv-based dev environment, testing changes with build commands, and pre-commit hooks.
- **LICENSE** - Project license file.
- **.envrc** - Direnv configuration that loads the Nix development environment automatically when entering the repository.
- **gitleaks.toml** - Configuration for the gitleaks secret scanning tool with allowed false-positive patterns.
- **.gitignore** - Excludes IDE files, Nix build artifacts, direnv state, and generated pre-commit configuration.
- **.pre-commit-config.yaml** - Symlink to the Nix-managed pre-commit hook configuration.

## Directories

- **modules/** - NixOS configuration modules split into shared common modules and hardware-specific utility modules.
- **devices/** - Per-machine hardware configurations defining monitors, CPU/GPU, storage, and kernel modules for each physical system.
- **docs/** - Documentation covering system commands, deployment, module/machine creation, secrets management, and remote builders.
- **patches/** - Security patch overlay applying CVE fixes not yet available in upstream nixpkgs.
- **secrets/** - Agenix-encrypted secrets (SSH keys, API tokens) with per-machine rekeyed variants.
- **builders/** - Hetzner Cloud disk image configuration for ephemeral remote Nix build servers.
- **cache/** - Hetzner Cloud disk image configuration for the persistent niks3 binary cache server.
- **backups/** - ZFS backup automation module using sanoid for snapshots and syncoid for replication.
- **util/** - Shared utility functions used across modules.
- **yubikeys/** - Public key files for YubiKey hardware security tokens used for secret encryption.
- **.claude/** - Claude Code AI configuration including hooks, settings, and skill definitions for CVE resolution.
