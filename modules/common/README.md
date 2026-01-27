# Common Modules

This directory contains shared NixOS configuration modules used across all systems. Each module is organized as a directory with a `default.nix` entry point.

## Table of Contents

- [Core System](#core-system)
- [Security](#security)
- [Development Tools](#development-tools)
- [System Services](#system-services)
- [Desktop & Display](#desktop--display)
- [Multimedia](#multimedia)
- [Utilities & Peripherals](#utilities--peripherals)

---

## Core System

### [boot](./boot/)
Security-hardened boot configuration using lanzaboote for UEFI Secure Boot.
- GrapheneOS memory allocator for improved security
- Kernel 6.18 with comprehensive initrd modules (NVME, USB 3.0, SATA, ZFS)
- 100+ sysctl security parameters (ASLR, SMEP, SMAP, KPTI mitigations)
- Kernel hardening: disabled io_uring, restricted ptrace, disabled debugfs
- IOMMU enforcement for DMA attack prevention
- zram swap for memory compression
- Dual EFI boot partitions (`/boot1` and `/boot2`) with automatic sync
- TPM2 tools and secure boot management utilities

### [users](./users/)
User account configuration and group membership.
- Creates primary user with zsh shell
- Configures group memberships (scanner, lp, corectrl, plugdev)

### [locale](./locale/)
Internationalization and localization settings.
- Default locale: en_US.UTF-8
- US keyboard layout configuration
- Automatic timezone updates via geoclue2 and automatic-timezoned
- Uses BeaconDB as geolocation provider

### [time](./time/)
Time synchronization using Chrony with NTS (Network Time Security).
- Multiple NTS-enabled servers (Cloudflare, Netnod, PTB, etc.)
- Requires 3 sources minimum for time validation
- Disabled client logging for privacy
- EF DSCP marking for QoS

### [global-options](./global-options/)
Shared configuration options accessible across all modules.
- `username`: Primary user's username
- `homeDir`: User's home directory
- `monitors`: Display configuration (mode, position, number, notifications)

### [home](./home/)
XDG Base Directory specification and home-manager integration.
- Standard XDG directories (desktop, documents, downloads, etc.)
- MIME type associations

---

## Security

### [security](./security/)
System-wide security hardening and privilege escalation.
- doas instead of sudo for privilege escalation
- PAM with Yubikey U2F authentication (sufficient mode)
- auditd for system auditing
- polkit for authorization
- Sudo compatibility wrapper for legacy scripts

### [secrets](./secrets/)
Secret management using agenix and agenix-rekey.
- YubiKey-based master identities
- Machine-specific rekeyed secrets directory
- Local storage mode for secrets

### [ssh](./ssh/)
SSH agent configuration for home-manager user.

### [sshd](./sshd/)
SSH daemon configuration.

### [yubikey](./yubikey/)
YubiKey hardware security key integration.

### [passwords](./passwords/)
Password and secrets management configuration.

### [crypto](./crypto/)
Cryptographic tools and utilities.

---

## Development Tools

### [git](./git/)
Comprehensive Git configuration with AI-assisted workflows.
- SSH signing with ED25519 keys
- Custom scripts: `git-clone-for-worktree`, `ai-commit`, `ai-reword`, `ai-rebase`
- mergiraf for syntax-aware merge conflict resolution
- Git LFS support
- difftastic for structural diffs
- zdiff3 conflict style with git rerere
- Multiple identity support (personal and work)
- Submodules: [lazygit](./git/lazygit/), [lazyworktree](./git/lazyworktree/)

### [nvim](./nvim/)
Neovim editor configuration (Kickstart-based).
- Lua-based configuration
- Language servers: Lua, Nix, TypeScript, Bash, Python, YAML, HTML/CSS/JSON
- Formatters: stylua, nixpkgs-fmt, prettier, black, isort, shfmt
- Linters: markdownlint, shellcheck, eslint
- Tree-sitter integration
- Auto-generated color theme from stylix

### [tmux](./tmux/)
Terminal multiplexer with workmux integration.
- workmux CLI for git worktrees + tmux workflows
- Prefix: Ctrl-A with vim-style navigation
- Plugins: vim-tmux-navigator, yank, resurrect, dracula theme, continuum
- sesh session switcher integration
- Claude AI integration for branch naming (`wmab` command)
- Mouse support and 24-hour time display

### [shell](./shell/)
Zsh shell configuration and modern CLI tools.
- Wezterm terminal emulator with Wayland support
- Modern CLI replacements: bat, eza, dut, ripgrep, fd, fzf
- Starship prompt with git status
- Atuin for shell history (local, no sync)
- Zoxide for directory jumping
- Oh-my-zsh with plugins (alias-finder, colored-man-pages, fancy-ctrl-z)
- GPG agent integration

### [direnv](./direnv/)
Directory-specific environment management.
- nix-direnv for development environments
- Bash and Zsh integration
- 30-minute warning timeout

### [nix](./nix/)
Nix package manager configuration.
- Automatic garbage collection (daily, keeps 7 days)
- Idle CPU scheduling for nix daemon
- Max jobs: 16, 1GB download buffer
- Determinate Systems cache
- Daily store optimization (00:15)

### [claude](./claude/)
Claude AI integration and tooling.
- Agent configurations
- Command templates
- Git hooks for AI-assisted workflows
- Skills configuration (including PRD management)

---

## System Services

### [networking](./networking/)
Network configuration with privacy-focused DNS.
- NetworkManager with custom DNS
- dnscrypt-proxy2 for DNS-over-HTTPS with DNSSEC
- Privacy-focused resolvers: Mullvad and Quad9
- DNS caching (4096 entries)
- Firewall with WireGuard port (51820)
- IPv6 disabled
- HTTP/3 (QUIC) support for DNS

### [audio](./audio/)
PipeWire audio system configuration.
- WirePlumber for device management
- Device priorities: Scarlett Solo Mic (input), FiiO K3 (output)
- Scarlett Solo disabled as output sink
- USB audio reset service after sleep/resume
- Tools: pavucontrol, helvum, playerctl, alsa-utils

### [bluetooth](./bluetooth/)
Bluetooth configuration.
- Hardware support enabled at boot
- Experimental features enabled
- Tools: Blueman (GUI), Bluetui (TUI)

### [containers](./containers/)
Container management with Podman.
- Overlay storage driver
- Rootless container support with subuid/subgid
- netavark network backend
- Weekly auto-prune
- cgroup2 delegation for rootless users
- podman-compose for multi-container orchestration

### [systemd](./systemd/)
Systemd daemon configuration.
- Core dump storage disabled

### [graphics](./graphics/)
GPU and graphics configuration.
- OpenGL with 32-bit support

### [wayland](./wayland/)
Wayland session configuration.
- Environment variables for app compatibility (SDL, Qt, Java, Mozilla, Electron)
- Electron flags configuration

### [zfs](./zfs/)
ZFS filesystem support.

### [syncthing](./syncthing/)
File synchronization across devices.
- Configured devices: zenbook, bambee_mac, pixel6, jack-mini-pc
- Synchronized folders: Keepass database, Pixel camera (receive-only)

---

## Desktop & Display

### [sway](./sway/)
Sway tiling window manager (Wayland-native).
- GTK wrapper support
- Wayland utilities: swaylock, swayidle, waybar, wofi, swayr, grim/slurp, satty
- Custom scripts for window management
- XDG portal configuration for screen sharing
- Extensive keybindings with Mod4 (Super) modifier
- Submodules: [copyq](./sway/copyq/), [waybar](./sway/waybar/), swaync, swayidle

### [theme](./theme/)
System-wide theming using Stylix.
- Color scheme: Tokyo City Dark (base16)
- Fonts:
  - Monospace: JetBrains Mono (Nerd Font)
  - Sans-serif: Noto Sans
  - Serif: Noto Serif
  - Emoji: Noto Color Emoji
- Cursor: Bibata Modern Ice

### [keyboards](./keyboards/)
Keyboard configuration and firmware tools.

---

## Multimedia

### [browser](./browser/)
Web browser configuration.
- Firefox in FHS environment (bypasses system allocator)
- Chromium as secondary browser
- Chawan text-mode web browser
- Tridactyl vim-like extension with custom keybindings
- MIME type handlers for HTTP/HTTPS

### [video-player](./video-player/)
Video playback configuration.
- mpv (Wayland-native) as primary player
- VLC as fallback
- MIME types for all video formats

### [video-editor](./video-editor/)
Video editing tools.

### [image-viewer](./image-viewer/)
Image viewing configuration.

### [image-editor](./image-editor/)
Image editing tools.

### [imagemagick](./imagemagick/)
ImageMagick command-line image manipulation.

### [recording](./recording/)
Audio/video recording and streaming.
- OBS Studio for streaming/recording
- scarlett2 for Focusrite firmware management
- alsa-scarlett-gui for audio device control

### [music-player](./music-player/)
Music playback configuration.

### [transcription](./transcription/)
Audio transcription tools.

### [virtual-camera](./virtual-camera/)
Virtual camera configuration for streaming.

---

## Utilities & Peripherals

### [packages](./packages/)
Miscellaneous system packages (170+ packages).
- Languages: Go, Rust, Python 3.14, Java, PowerShell, Node.js, Bun
- Development: gnumake, gcc, flex, bison, gdb
- Kubernetes: kubectl, kubectx, k9s
- Media: ffmpeg, ImageMagick, GIMP
- Networking: mtr, bind DNS tools, WireGuard, OpenSSL
- Gaming: Lutris, GameMode, Gamescope, Wine (Wayland)
- File sharing: croc

### [scripts](./scripts/)
Custom utility scripts for system administration.
- `un.sh` rebuild script for NixOS deployment

### [file-explorer](./file-explorer/)
File manager configuration.
- Submodules: [ranger](./file-explorer/ranger/) (terminal), thunar (GUI)

### [pdf](./pdf/)
PDF viewing and manipulation.

### [printer](./printer/)
CUPS printing system and drivers.

### [scanner](./scanner/)
Document scanning support.

### [torrent](./torrent/)
BitTorrent client configuration.

### [btop](./btop/)
System resource monitor TUI.

### [finance](./finance/)
Financial software and tools.

### [sqlite](./sqlite/)
SQLite database tools.

### [messaging](./messaging/)
Messaging and communication applications.
