# Table of Contents — modules/utility/

- **debug.nix** - Comprehensive debug module that dumps system state, hardware info, and NixOS configuration details for troubleshooting.
- **cache-module.nix** - Shared binary cache configuration (substituters and public keys) applied to all NixOS systems and disk images.
- **ccache-r2.nix** - Shared ccache-R2 configuration (s3fs mount, s5cmd sync, tmpfiles, sandbox paths) used by local machines and remote builders.
- **syncthing.nix** - Declarative Syncthing utility module with NixOS options, central folder/device registries, and assembled peer/folder config. Designed to work standalone without common modules or Home Manager.
