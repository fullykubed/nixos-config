# Table of Contents — modules/common/

- **README.md** - Comprehensive reference documentation for all 60+ shared modules organized by category.

## Core System

- **boot/** - Security-hardened UEFI boot with Secure Boot via lanzaboote, kernel hardening, and IOMMU isolation.
- **cpu/** - CPU vendor configuration with microcode updates and KVM support for AMD and Intel processors.
- **gpu/** - Discrete GPU driver configuration with optional AMD GPU support including CoreCtrl and radeontop.
- **global-options/** - Defines shared configuration options (username, home directory, monitor count) used across modules.
- **home/** - Configures XDG Base Directory specification and MIME type associations.
- **home-manager/** - Home Manager user configuration with stylix theming, nix-index integration, and state versions.
- **locale/** - Sets internationalization to en_US.UTF-8 with US keyboard layout and automatic timezone via geoclue2.
- **networking/** - Sets up NetworkManager with dnscrypt-proxy2 for DNS-over-HTTPS encrypted DNS resolution.
- **nix/** - Configures Nix daemon optimization, automatic garbage collection, and flake settings.
- **systemd/** - Configures systemd daemon settings and file descriptor limits.
- **time/** - Chrony NTP time synchronization with NTS security and multiple redundant time servers.
- **users/** - Creates the primary user account with Zsh shell and group memberships.
- **zfs/** - Enables ZFS filesystem support with dataset management.

## Security

- **security/** - Implements doas privilege escalation, PAM/YubiKey U2F authentication, and kernel audit logging.
- **secrets/** - Configures agenix secret management with YubiKey-based master identities for decryption.
- **passwords/** - Configures KeePassXC password manager with libsecret integration.
- **ssh/** - Configures the SSH agent for the home-manager user.
- **sshd/** - Sets up the SSH daemon with hardened security settings.
- **yubikey/** - Installs YubiKey management tools including manager, age plugin, and personalization utilities.
- **vulnix-scanner/** - Systemd timer that runs daily CVE vulnerability scans with a whitelist for known false positives.

## Development Tools

- **claude/** - Manages Claude AI integration including agent configurations, PRD workflow skills, and git hooks.
- **git/** - Comprehensive Git configuration with SSH signing, delta diff viewer, AI-assisted commit scripts, and lazygit.
- **nvim/** - Full Neovim setup with Lua configuration, 40+ plugins, language servers, formatters, and linters.
- **shell/** - Zsh shell with modern CLI replacements (eza, bat, fd, ripgrep), Starship prompt, and Atuin history sync.
- **tmux/** - Terminal multiplexer with workmux for git worktree management and vim-style navigation.
- **direnv/** - Directory-specific environment management using nix-direnv for automatic Nix shell activation.
- **containers/** - Podman container runtime with overlay storage, rootless support, and podman-compose.
- **sqlite/** - Installs SQLite database tools and exports the library path.
- **scripts/** - Custom utility shell scripts for system administration tasks.

## Desktop & Display

- **sway/** - Sway tiling Wayland compositor with waybar, swaync notifications, swayidle, copyq clipboard, and custom scripts.
- **wayland/** - Sets Wayland environment variables for application compatibility (SDL, Qt, Java, Mozilla, Electron).
- **theme/** - System-wide theming via Stylix using Tokyo City Dark colorscheme, JetBrains Mono font, and Noto fallbacks.
- **graphics/** - Enables OpenGL with 32-bit support for GPU rendering.
- **keyboards/** - Enables ZSA keyboard support and firmware flashing tools.
- **bluetooth/** - Enables Bluetooth hardware with experimental features, blueman GUI, and bluetuith TUI.
- **audio/** - Configures PipeWire audio system with device priorities, WirePlumber rules, and USB audio tools.

## File Management & Browsing

- **browser/** - Configures Firefox (in FHS environment), Chromium, and Chawan browsers with vim-like keybindings.
- **file-explorer/** - Sets up Thunar GUI file manager and Ranger terminal file manager with custom configuration.
- **image-viewer/** - Configures swayimg as the default Wayland-native image viewer.
- **pdf/** - Sets up Okular as the default PDF viewer and editor.
- **syncthing/** - File synchronization service across multiple devices (phones, laptops, desktops).

## Communication

- **messaging/** - Installs Discord, Signal Desktop, Slack, and Signal CLI messaging applications.
- **away-notify/** - Pushover notification service that alerts when the user has been idle for 5+ minutes.

## Multimedia

- **music-player/** - Terminal-based Spotify player (spotify-player) using librespot for local playback.
- **video-player/** - Configures mpv as the primary Wayland-native video player with VLC as fallback.
- **video-editor/** - Installs Shotcut video editor with platform-specific Wayland configuration.
- **recording/** - Installs OBS Studio for screen recording and Scarlett audio interface firmware tools.
- **virtual-camera/** - Loads v4l2loopback and snd-aloop kernel modules for virtual camera and microphone streaming.
- **image-editor/** - Installs draw.io for diagram and flowchart editing.
- **transcription/** - Manages voxtype voice-to-text transcription tool configuration.

## Other Applications

- **btop/** - Installs btop system resource monitor TUI.
- **packages/** - Installs 170+ miscellaneous packages spanning languages, development tools, media utilities, and gaming.
- **finance/** - Installs HomeBank personal finance management application.
- **crypto/** - Installs cryptocurrency wallets (Wasabi Bitcoin, Monero GUI, MyCrypto).
- **torrent/** - Installs and configures qBittorrent torrent client.
- **printer/** - Enables the CUPS printing system.
- **scanner/** - Configures Brother network scanner with brscan5 drivers, SANE integration, and naps2 scanning application.
- **wakeup/** - Optional systemd service that disables ACPI wakeup triggers to prevent unwanted wake-from-sleep events.
- **binary-cache/** - Configures remote Nix binary cache access with SSH-based authentication and a management CLI.
- **hetzner/** - Installs Hetzner Cloud CLI tools (hcloud and hcloud-upload-image).
- **remote-builders/** - Configures remote Nix build machine connections with SSH authentication and the builders CLI tool.
