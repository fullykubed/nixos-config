# Table of Contents — images/controller/

- **default.nix** - Entry point that imports the controller server image configuration.
- **image.nix** - System basics: imports feature modules, defines users, nix daemon, firewall, and system packages.
- **hardware.nix** - Hetzner Cloud hardware configuration with UEFI/GRUB boot, virtio modules, and 80GB disk for the controller VM.
- **headscale.nix** - Headscale control plane, Tailscale client, systemd hardening, and Cloudflare DNS update service.
- **caddy.nix** - Caddy TLS reverse proxy for headscale with systemd ordering and hardening.
- **niks3.nix** - niks3 binary cache with Cloudflare R2 storage, PostgreSQL, systemd hardening, and tmpfiles for secrets.
- **volume.nix** - Persistent Hetzner Cloud Volume mount service with bind-mounts to service state directories.
- **ssh.nix** - OpenSSH server, cloud-init integration, and host key injection.
- **upload-image.sh** - Script that builds the controller server disk image and uploads it to Hetzner Cloud as a snapshot.
