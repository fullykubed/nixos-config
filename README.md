# Personal [NixOS](https://nixos.org/) Configuration

Personal NixOS configuration for multiple machines using Nix flakes, [Home Manager](https://nix-community.github.io/home-manager/), and declarative system management.

## Philosophy

- **Declarative everything** - The entire system is version-controlled and reproducible
- **Modular composition** - Independent, reusable modules over monolithic configuration
- **Security by default** - Hardened kernel, YubiKey integration, sandboxed applications
- **Centralized versioning** - All external dependencies defined in one place
- **Keyboard-driven** - Sway, Neovim, and other TUIs (complements my [custom keyboard config](https://github.com/fullykubed/glove80))

## Features

- **Multi-machine support** - Shared modules with machine-specific overrides
- **Security**
  - Secure boot with [Lanzaboote](https://github.com/nix-community/lanzaboote)
  - Kernel hardening inspired by [nix-mineral](https://github.com/cynicsketch/nix-mineral)
  - Application sandboxing with [nix-bwrapper](https://github.com/Naxdy/nix-bwrapper)
  - Encrypted secrets with [agenix](https://github.com/ryantm/agenix) and [agenix-rekey](https://github.com/oddlama/agenix-rekey) for per-machine rekeying
  - Password management with [KeePassXC](https://keepassxc.org/), [SSH agent integration](https://keepassxc.org/docs/KeePassXC_UserGuide#_ssh_agent_integration), and [Syncthing](https://syncthing.net/) sync
  - [doas](https://github.com/Duncaen/OpenDoas) replacement for sudo with YubiKey authentication
- **Desktop**
  - [Sway](https://swaywm.org/) tiling Wayland compositor
  - [Waybar](https://github.com/Alexays/Waybar) status bar
  - [WezTerm](https://wezfurlong.org/wezterm/) terminal
  - [SwayNC](https://github.com/ErikReider/SwayNotificationCenter) notification center
  - [Tridactyl](https://github.com/tridactyl/tridactyl) for vim-like browser control
- **Development**
  - [Neovim](https://neovim.io/) with Kickstart-based configuration
  - [tmux](https://github.com/tmux/tmux) terminal multiplexer
  - [Zsh](https://www.zsh.org/) shell
  - Custom Git settings for different development contexts
- **AI**
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) sandboxed with bubblewrap and given custom skills, commands, agents, and [MCP](https://modelcontextprotocol.io/) servers
  - `q`, `qq`, `qqq` shell aliases for quick AI queries from the terminal
  - [voxtype](https://github.com/fullykubed/voxtype) for push-to-talk transcription to control agents
  - [workmux](https://github.com/fullykubed/workmux) for agent multiplexing with tmux
- **Theming** - System-wide styling with [Stylix](https://github.com/danth/stylix)
- **Storage** - [ZFS](https://openzfs.org/) filesystem with encryption and automated snapshots

## Repository Structure

```
.
├── flake.nix                 # Main flake entry point
├── configuration.nix         # Base system configuration
├── devices/                  # Machine-specific configurations
├── modules/
│   ├── common/              # Shared modules across all systems
│   └── utility/             # Hardware-specific utilities
├── backups/                 # ZFS backup configuration
├── secrets/                 # Encrypted secrets (agenix)
├── yubikeys/                # Public keys for secret encryption
└── docs/                    # Documentation
```

## Documentation

- [Commands](docs/commands.md) - System rebuild commands
- [Deployment](docs/deployment.md) - Building and deploying configurations
- [Adding Modules](docs/adding-modules.md) - Creating new configuration modules
- [Adding Machines](docs/adding-machines.md) - Configuring new systems
- [Secret Management](docs/secrets.md) - Managing encrypted secrets with agenix

## License

MIT License - see [LICENSE](LICENSE) for details.

## Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [Agenix Documentation](https://github.com/ryantm/agenix)
