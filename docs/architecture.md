# Architecture Overview

NixOS desktop machines defined in a single flake, plus Hetzner Cloud disk images for ephemeral remote builders and a binary cache.

## How a system is assembled

`flake.nix` calls `mkNixosSystem` (`lib/mk-nixos-system.nix`) once per machine. It wires all flake inputs together into a `nixpkgs.lib.nixosSystem` call with:

1. **Device module** (`devices/*.nix`) -- sets hardware-specific values: filesystems, monitors, `cpuVendor`, `gpuVendor`, networking.
2. **Common modules** (`modules/default.nix`) -- modules imported unconditionally for every machine.
3. **Flake-provided modules** -- Lanzaboote (Secure Boot), Stylix (theming), Home Manager, agenix (secrets), etc.

All per-machine differentiation lives in the device module.

## Key patterns

**Custom options as the glue** -- `modules/common/global-options/` and individual modules define top-level options (`username`, `monitors`, `cpuVendor`, `cpuCount`, etc.). Device files set them; common modules consume them.

**Home Manager for user config** -- Home Manager is integrated via `modules/common/home-manager/`. User-level settings (shell aliases, program config, dotfiles) should go through `home-manager.users.${config.username}` rather than system-level options when possible. Most common modules already use this -- e.g. shell aliases in zsh, git config, SSH match blocks.

**Dual nixpkgs channels** -- In addition to the standard `pkgs`, `lib/nixpkgs-unstable.nix` exposes `nixpkgs-unstable` as a module argument with its own overlays option. Modules can pull bleeding-edge packages without touching stable.

**Hardened stdenv with mold** -- `modules/patches/stdenv/` overrides the global stdenv to add extra hardening flags, link all packages with [mold](https://github.com/rui314/mold), and disable reference checks so CVE patches on bootstrap packages don't break the build. Packages opt out of mold via `__noMold = true` or the `moldExcludedNames` list.

**Patches** -- `modules/patches/` has per-package directories, each an overlay module. Patches cover CVEs not yet upstream, fixes for packages broken by our hardened stdenv, and any other upstream issues. A daily `vulnix` timer scans for new vulnerabilities.

**Secrets** -- `agenix` + `agenix-rekey` with YubiKey master identities. Encrypted at rest in `secrets/`, rekeyed per-host, decrypted to `/run/agenix/` at activation.

**Remote builders** -- Hetzner Cloud VMs provisioned on-demand via an SSH `ProxyCommand`. When Nix connects to `builder-*`, a proxy script creates the server if needed. A `builders` CLI manages the fleet.

**Pinned versions** -- `lib/versions.nix` centralizes version strings and hashes for custom packages (workmux, voxtype, etc.) so modules don't embed version info inline.

## Directory structure

```
flake.nix              # Entry point
lib/
  mk-nixos-system.nix  # Wires inputs -> nixosSystem
  nixpkgs-unstable.nix # Unstable channel as module argument
  versions.nix         # Pinned versions/hashes for custom packages
  devshell/            # nix develop shell with pre-commit hooks
devices/               # Per-machine hardware config
modules/
  default.nix          # Imports all common modules
  common/              # Shared modules (unconditional)
  utility/             # Misc utility modules (cache config, etc.)
  patches/             # Per-package CVE overlay modules
docs/                  # Documentation
images/                # Hetzner Cloud disk image definitions
secrets/               # agenix-encrypted secrets + rekeyed per-host
yubikeys/              # YubiKey public identities
```

## Further reading

- [Installing a new machine](install/new-machine.md) -- end-to-end guide from device config to first boot
- [Working with modules](modules/working-with-modules.md) -- organization, guidelines, and creating new modules
- [Deployment](deployment.md) -- building and deploying system configurations
- [Secrets](secrets.md) -- agenix secret management workflow
- [Build system](build-system/README.md) -- stdenv, compiler cache, remote builders, and binary cache
