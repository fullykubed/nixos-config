# Table of Contents — lib/

- **versions.nix** - Centralized version pins and hashes for all custom-built packages referenced by modules.
- **mk-nixos-system.nix** - NixOS system builder that assembles a complete configuration from a device module and flake inputs.
- **packages/** - Shared custom package definitions not available in nixpkgs, used by both NixOS modules and the devshell.
- **devshell/** - Development shell, nixfmt formatter, pre-commit hook configuration, and the bun version consistency checker script.
- **installer/** - Custom NixOS installer ISO module that pre-builds all machine closures for offline installation via `install-machine`.
- **util/** - Shared helper functions (systemd hardening, yasm-to-nasm replacement) used across modules.
