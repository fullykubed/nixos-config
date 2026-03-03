# Personal NixOS Configuration

> [!WARNING]
> This is my personal NixOS configuration and is provided for example purposes only. It is tailored to my specific hardware, workflow, and preferences. Use at your own risk — copying this configuration directly is unlikely to work without significant adaptation.

Personal [NixOS](https://nixos.org/) configuration for multiple machines using [Nix flakes](https://nixos.wiki/wiki/Flakes), [Home Manager](https://nix-community.github.io/home-manager/), and declarative system management. Uses [Determinate Nix](https://github.com/DeterminateSystems/nix) for improved performance.

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
  - [GrapheneOS hardened memory allocator](https://github.com/GrapheneOS/hardened_malloc) for exploit mitigation
  - Application sandboxing with [nix-bwrapper](https://github.com/Naxdy/nix-bwrapper)
  - Automatic scanning with [vulnix](https://github.com/nix-community/vulnix) along with custom CVE patching overlay for vulnerabilities
  - Rebuild all packages from source with additional compiler hardening flags 
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

See [TOC.md](TOC.md) for a full listing of all files and directories.

## Documentation

See [docs/TOC.md](docs/TOC.md) for a full listing of available documentation.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [Agenix Documentation](https://github.com/ryantm/agenix)
