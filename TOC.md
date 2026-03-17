# Table of Contents

## Files

- **flake.nix** - Main Nix flake defining inputs, system configurations for two machines (tower and mini-pc), and build outputs for builder/cache disk images.
- **README.md** - Project overview documenting the multi-machine NixOS setup with emphasis on declarative configuration, modular composition, and security features.
- **CONTRIBUTING.md** - Development guidelines covering the direnv-based dev environment, testing changes with build commands, and pre-commit hooks.
- **LICENSE** - Project license file.
- **.envrc** - Direnv configuration that loads the Nix development environment automatically when entering the repository.
- **gitleaks.toml** - Configuration for the gitleaks secret scanning tool with allowed false-positive patterns.
- **.gitignore** - Excludes IDE files, Nix build artifacts, direnv state, and generated pre-commit configuration.
- **.pre-commit-config.yaml** - Symlink to the Nix-managed pre-commit hook configuration.

## Directories

- **modules/** - NixOS configuration modules split into shared common modules, hardware-specific utility modules, security patches, and shared utilities.
- **devices/** - Per-machine hardware configurations defining monitors, CPU/GPU, storage, and kernel modules for each physical system.
- **docs/** - Documentation covering system commands, deployment, module/machine creation, secrets management, and remote builders.
- **images/** - Hetzner Cloud disk image configurations for ephemeral remote build servers and the persistent binary cache server.
- **lib/** - Extracted flake helper files including version pins, overlays, custom packages, and development shell configuration.
- **secrets/** - Agenix-encrypted secrets (SSH keys, API tokens, Secure Boot keys) with per-machine rekeyed variants and Secure Boot public PKI files.
- **yubikeys/** - Public key files for YubiKey hardware security tokens used for secret encryption.
- **.claude/** - Claude Code AI configuration including hooks, settings, and skill definitions for CVE resolution.
