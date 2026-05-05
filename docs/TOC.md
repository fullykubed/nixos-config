# Table of Contents — docs/

- **commands.md** - Documents the `un.sh` rebuild script with options for quick rebuild, boot-only, flake updates, and offline builds.
- **deployment.md** - Explains the `un` rebuild script, `una` AI autofix, and links to the nightly auto-upgrade docs.
- **nightly-auto-upgrade.md** - Nightly systemd timer that clones upstream main and runs nixos-rebuild switch, with rollback on activation failure and Pushover notifications.
- **adding-modules.md** - Instructions for creating new NixOS modules in the common or utility directories following the standard module pattern.
- **install/** - Installation documentation: step-by-step new machine guide, installer architecture with diagrams, and troubleshooting.
- **secrets.md** - Describes agenix-based secret management with per-machine rekeying and runtime decryption.
- **build-system/** - Comprehensive build system documentation: custom stdenv (mold, ccache, hardening), R2-backed compiler cache, ephemeral Hetzner Cloud builders, and niks3 binary cache.
- **cli/** - Documentation for the `j` CLI: swiss-army knife consolidating all custom scripts and tooling into a single binary. Architecture (Bun/Effect/OpenTUI), service layer, command reference, and build/test instructions.
- **claude-architecture.md** - Comprehensive architecture reference for Claude Code integration: sandbox, credential proxy, skills, MCP servers, hooks, shell integration, configuration hierarchy, and secrets.
