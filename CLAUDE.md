# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS configuration repository that manages system configurations for multiple machines using Nix flakes. The repository contains:
- NixOS system configurations for workstations (`fullykubed-tower`, `fullykubed-mini-pc`)
- Home Manager configurations for user environment
- Modular configuration structure with reusable components
- Secret management using agenix and agenix-rekey

## Build and Deployment Commands

### System Rebuild Commands
```bash
# Quick rebuild and switch to new configuration (uses current hostname, with --fast)
./modules/common/scripts/scripts/un.sh

# Rebuild boot configuration only
./modules/common/scripts/scripts/un.sh --boot
# or
./modules/common/scripts/scripts/un.sh -b

# Update flake inputs and rebuild
./modules/common/scripts/scripts/un.sh --update
# or
./modules/common/scripts/scripts/un.sh -u

# Build without network access (offline mode)
./modules/common/scripts/scripts/un.sh --offline
# or
./modules/common/scripts/scripts/un.sh -o

# Combine flags (e.g., update and boot rebuild)
./modules/common/scripts/scripts/un.sh -u -b

# Show help and available options
./modules/common/scripts/scripts/un.sh --help

# Manual rebuild for specific systems
sudo nixos-rebuild switch --fast --flake /etc/nixos#fullykubed-tower
sudo nixos-rebuild switch --fast --flake /etc/nixos#fullykubed-mini-pc
```

### Development Commands
```bash
# Format all Nix files
nix fmt

# Enter development shell with formatting tools and agenix-rekey
nix develop

# Rekey secrets (after modifying secrets configuration)
nix run .#agenix-rekey
```

## Architecture

### Flake Structure
- **flake.nix**: Main entry point defining nixosConfigurations for each machine
- **configuration.nix**: Base system configuration that imports all modules
- **devices/**: Machine-specific configurations (hardware, networking, monitors)
  - `workstation-tower.nix`: Desktop configuration with AMD CPU/GPU
  - `mini-pc.nix`: Mini PC configuration with Intel CPU

### Module Organization
- **modules/common/**: Shared configurations across all systems
  - System services (boot, networking, bluetooth, audio, etc.)
  - Desktop environment (Sway/Wayland configuration)
  - Development tools (git, ssh, direnv, IDE configurations)
  - Application configurations (browser, video/image tools, etc.)
- **modules/utility/**: Hardware-specific utility modules
  - CPU/GPU configurations (AMD, Intel)
  - Device-specific utilities

### Home Manager Integration
- **home-manager/**: User-specific configurations
  - `default.nix`: Main home-manager entry point
  - `nvim/`: Neovim configuration (Kickstart-based setup)

### Secret Management
- Uses agenix for encrypted secrets
- Secrets are rekeyed per-machine using public keys in `yubikeys/`
- Encrypted secrets stored in `secrets/rekeyed/[hostname]/`

## Key Configuration Patterns

### Adding a New Module
1. Create module file in appropriate `modules/` directory
2. Import in `configuration.nix`
3. Module should follow the pattern: `{ config, pkgs, lib, ... }: { ... }`

### Managing Secrets
1. Add secret to `secrets/` directory
2. Configure in agenix setup
3. Run `nix run .#agenix-rekey` to rekey for all systems

### System Deployment Flow
1. Make changes to configuration files
2. Test with `nixos-rebuild build --flake .#[hostname]`
3. Deploy using `./modules/common/scripts/scripts/un.sh` which:
   - Copies configuration to `/etc/nixos` 
   - Runs `nixos-rebuild switch`

## Important Notes

- The `un.sh` script (in `modules/common/scripts/scripts/`) automatically uses the current hostname when rebuilding
- All package overlays make nixpkgs-unstable available as `pkgs.unstable`
- Secure boot is configured via lanzaboote module
- The system uses Determinate Nix implementation
- Do NOT make any file edits unless asked.
