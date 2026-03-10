# Table of Contents — modules/

- **common/** - 57 shared NixOS modules that are imported by all machines, covering everything from boot and networking to desktop environment and multimedia applications.
- **utility/** - Hardware-specific NixOS modules for CPU, GPU, and peripheral configurations that are selectively imported per device.
- **patches/** - Security patch overlay applying CVE fixes not yet available in upstream nixpkgs, organized as per-package folders.
