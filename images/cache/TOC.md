# Table of Contents — images/cache/

- **default.nix** - Entry point that imports the cache server image configuration.
- **image.nix** - Complete NixOS system configuration for the niks3 binary cache server with PostgreSQL, Cloudflare R2 storage, and SSH access.
- **hardware.nix** - Hetzner Cloud hardware configuration with UEFI/GRUB boot, virtio modules, and 80GB disk for the PostgreSQL database.
- **upload-image.sh** - Script that builds the cache server disk image and uploads it to Hetzner Cloud as a snapshot.
