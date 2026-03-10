# Table of Contents — images/builder/

- **default.nix** - Entry point that imports the builder image configuration and documents the directory structure.
- **image.nix** - Complete NixOS system configuration for ephemeral builder VMs including SSH, cloud-init, cache uploads, and inactivity monitoring.
- **hardware.nix** - Hetzner Cloud hardware configuration with UEFI/GRUB boot, virtio kernel modules, and 40GB disk sizing.
- **hardening.nix** - Security hardening for cloud builder VMs applying kernel sysctl parameters, boot hardening, and module blacklisting.
- **inactivity-monitor.nix** - Systemd service that monitors for idle builders and auto-deletes the server after 15 minutes of inactivity.
- **upload-image.sh** - Script that builds the builder disk image and uploads it to Hetzner Cloud as a snapshot.
