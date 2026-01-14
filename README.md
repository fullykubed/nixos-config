# Jack's NixOS Configuration

Personal NixOS configuration for multiple machines using Nix flakes, Home Manager, and declarative system management.

## Features

- **Multi-machine support** - Configurations for desktop workstations and mini PC
- **Modular architecture** - Reusable components across systems
- **Home Manager integration** - User environment and dotfiles management
- **Secure boot** - Lanzaboote integration for UEFI secure boot
- **Secret management** - Encrypted secrets using agenix with per-machine rekeying
- **Wayland desktop** - Sway window manager with modern Wayland stack
- **Development ready** - Pre-configured development tools and environments

## Quick Start

### System Rebuild

```bash
# Quick rebuild and switch (uses current hostname, with --fast)
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

# Manual rebuild for specific systems
sudo nixos-rebuild switch --fast --flake /etc/nixos#fullykubed-tower
sudo nixos-rebuild switch --fast --flake /etc/nixos#fullykubed-mini-pc
```

### Development

```bash
# Format all Nix files
nix fmt

# Enter development shell
nix develop

# Rekey secrets after modification
nix run .#agenix-rekey
```

## Repository Structure

```text
.
├── flake.nix                 # Main flake entry point
├── configuration.nix         # Base system configuration
├── devices/                  # Machine-specific configurations
├── modules/
│   ├── common/               # Module configurations shared across all installs
│   └── utility/              # Hardware-specific utilities
├── secrets/                  # Encrypted secrets (agenix)
│   ├── *.age                 # Age-encrypted secrets
│   └── rekeyed/              # Per-machine encrypted secrets
└── yubikeys/                 # Public keys for secret encryption
```

## Configured Machines

* `fullykubed-mini-pc`: Intel-based mini PC workstation
* `fullykubed-tower`: AMD-based desktop workstation

## Key Components

### Desktop Environment
- **Window Manager**: Sway (Wayland compositor)
- **Status Bar**: Waybar
- **Application Launcher**: Rofi (Wayland fork)
- **Terminal**: Alacritty
- **Notifications**: SwayNC (Sway Notification Center)

### Development Tools
- **Editor**: Neovim (Kickstart-based configuration)
- **Version Control**: Git with GPG signing
- **Languages**: Go, Rust, Python, Node.js
- **Shell**: Zsh with Oh My Zsh
- **Terminal Multiplexer**: Zellij

### System Features
- **Audio**: PipeWire with WirePlumber
- **Bluetooth**: Full stack with audio support
- **Networking**: NetworkManager
- **Containers**: Docker and Podman
- **Virtualization**: QEMU/KVM with virt-manager

## Secret Management

This configuration uses [agenix](https://github.com/ryantm/agenix) for managing encrypted secrets:

1. Secrets are stored encrypted in [`secrets/`](secrets/)
2. Each machine has its own public key in [`yubikeys/`](yubikeys/)
3. Secrets are automatically rekeyed for each machine
4. Decrypted at runtime into `/run/agenix/`

To add a new secret:
```bash
# Create and edit secret
agenix -e secrets/new-secret.age

# Rekey for all machines
nix run .#agenix-rekey
```

## Customization

### Adding a New Module

1. Create module file in [`modules/common/`](modules/common/) or [`modules/utility/`](modules/utility/)
2. Import in [`configuration.nix`](configuration.nix)
3. Follow the standard module pattern:
```nix
{ config, pkgs, lib, ... }: {
  # Module configuration
}
```

### Adding a New Machine

1. Create device configuration in [`devices/`](devices/)
2. Add nixosConfiguration in [`flake.nix`](flake.nix)
3. Add public key to [`yubikeys/`](yubikeys/) for secret management
4. Run `nix run .#agenix-rekey` to rekey secrets

## Deployment

The [`un.sh`](modules/common/scripts/scripts/un.sh) script handles deployment:

1. Copies configuration to `/etc/nixos`
2. Runs `nixos-rebuild switch` with appropriate flags
3. Automatically uses the current hostname for the flake target

## License

Personal configuration - feel free to use as reference or inspiration for your own NixOS setup.

## Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [Agenix Documentation](https://github.com/ryantm/agenix)