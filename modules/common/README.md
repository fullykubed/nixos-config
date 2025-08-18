# Common Modules

This directory contains shared NixOS configuration modules used across all systems.

## Module Overview

- **audio.nix** - Configures PipeWire audio system with WirePlumber for modern audio management
- **bluetooth.nix** - Enables Bluetooth support with audio device integration and management tools
- **boot.nix** - Configures bootloader, kernel parameters, secure boot, and system initialization
- **browser.nix** - Sets up Brave browser as the default web browser with custom policies
- **claude/** - Configures Claude AI assistant with custom settings and API integration
- **containers/** - Sets up Docker and Podman container runtimes with storage configuration
- **crypto.nix** - Provides cryptocurrency and blockchain development tools and utilities
- **direnv.nix** - Enables automatic directory-based environment management for development workflows
- **file-explorer/** - Configures file managers including Ranger (terminal) and Thunar (GUI)
- **finance.nix** - Installs personal finance management and accounting software
- **git.nix** - Configures Git version control with GPG signing and user preferences
- **global-options.nix** - Sets system-wide NixOS options and feature flags
- **graphics.nix** - Configures GPU drivers, hardware acceleration, and graphics libraries
- **home.nix** - Integrates Home Manager for declarative user environment management
- **ide.nix** - Installs and configures integrated development environments and code editors
- **image-editor.nix** - Provides image editing and manipulation software like GIMP
- **image-viewer.nix** - Sets up lightweight image viewing applications
- **keyboards.nix** - Configures keyboard firmware tools and custom keyboard support
- **locale.nix** - Sets system locale, timezone, and internationalization settings
- **messaging.nix** - Installs instant messaging and communication applications
- **music-player.nix** - Provides music playback software and audio library management
- **networking.nix** - Configures NetworkManager, firewall, and core networking services
- **nix.nix** - Sets up Nix package manager features, flakes, and optimization settings
- **packages.nix** - Defines the core set of system packages installed on all machines
- **passwords.nix** - Configures password managers and secure credential storage
- **pdf.nix** - Installs PDF viewing and manipulation utilities
- **printer.nix** - Sets up CUPS printing system and printer drivers
- **recording.nix** - Provides screen recording and video capture software
- **scripts/** - Provides custom shell scripts for system management and automation utilities
- **secrets.nix** - Manages encrypted secrets using agenix for sensitive configuration
- **security.nix** - Hardens system security with AppArmor, firewall rules, and security policies
- **shell.nix** - Configures Zsh shell with Oh My Zsh, plugins, and terminal utilities
- **sqlite.nix** - Installs SQLite database tools and browser extensions
- **ssh.nix** - Configures SSH client settings and known hosts management
- **sshd.nix** - Sets up OpenSSH server with secure defaults and access controls
- **sway/** - Configures Sway tiling window manager with Waybar, GTK theming, and session management
- **syncthing.nix** - Enables Syncthing for peer-to-peer file synchronization
- **systemd.nix** - Configures systemd services, timers, and system management
- **torrent.nix** - Provides BitTorrent clients and peer-to-peer file sharing tools
- **users.nix** - Manages system users, groups, and authentication settings
- **video-editor.nix** - Installs video editing and post-production software
- **video-player.nix** - Sets up video playback applications with codec support
- **virtual-camera.nix** - Configures virtual camera devices for streaming and recording
- **wayland/** - Sets up Wayland display protocol support with Electron app compatibility flags
- **yubikey.nix** - Enables YubiKey hardware token support for authentication and GPG
- **zfs.nix** - Configures ZFS filesystem support with automatic snapshots and maintenance