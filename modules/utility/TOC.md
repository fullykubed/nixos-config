# Table of Contents — modules/utility/

- **debug.nix** - Comprehensive debug module that dumps system state, hardware info, and NixOS configuration details for troubleshooting.
- **nix-settings.nix** - Shared Nix daemon settings (experimental features, timeouts, substituters, trusted keys) applied to all NixOS systems and disk images.
- **ccache-r2.nix** - Shared ccache-R2 configuration (s5cmd download sync, s5cmd upload sync, tmpfiles, sandbox paths) used by local machines and remote builders.
- **syncthing.nix** - Declarative Syncthing utility module with NixOS options, central folder/device registries, and assembled peer/folder config. Designed to work standalone without common modules or Home Manager.
