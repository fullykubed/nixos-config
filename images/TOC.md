# Table of Contents — images/

- **builder/** - Hetzner Cloud disk image configuration for ephemeral remote Nix build servers with SSH, croc-based secret delivery, and inactivity monitoring.
- **common/** - Shared NixOS modules used by both builder and controller images (croc-receive secret transfer pipeline).
- **controller/** - Hetzner Cloud disk image configuration for the persistent controller server running Headscale, niks3, Caddy, croc relay, and PostgreSQL.
