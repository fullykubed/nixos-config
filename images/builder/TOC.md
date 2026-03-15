# Table of Contents — images/builder/

- **default.nix** - Entry point that imports the builder image configuration and documents the directory structure.
- **image.nix** - Top-level orchestration: imports all concern modules, sets system identity, defines users, and lists system packages.
- **hardware.nix** - Hetzner Cloud hardware configuration with UEFI/GRUB boot, virtio kernel modules, and 40GB disk sizing.
- **hardening.nix** - Security hardening for cloud builder VMs applying kernel sysctl parameters, boot hardening, and module blacklisting.
- **ssh.nix** - SSH server (port 3098), cloud-init integration, host key injection, and firewall rules.
- **ccache.nix** - Builder-specific ccache-R2 configuration wiring credentials from cloud-init.
- **nix-daemon.nix** - Nix daemon settings, job/core limits, experimental features, scheduling, and memory limits.
- **cache-pipeline.nix** - niks3 binary cache upload pipeline: post-build hook, SSH tunnel to cache server, upload queue service/path/timer.
- **inactivity-monitor.nix** - Systemd service that monitors for idle builders and auto-deletes the server after 15 minutes of inactivity.
- **upload-image.sh** - Script that builds the builder disk image and uploads it to Hetzner Cloud as a snapshot.
