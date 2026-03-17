# Table of Contents — docs/

- **commands.md** - Documents the `un.sh` rebuild script with options for quick rebuild, boot-only, flake updates, and offline builds.
- **deployment.md** - Explains the deployment script that copies configuration to /etc/nixos and runs nixos-rebuild with appropriate flags.
- **adding-modules.md** - Instructions for creating new NixOS modules in the common or utility directories following the standard module pattern.
- **install/** - Installation documentation: step-by-step new machine guide, installer architecture with diagrams, and troubleshooting.
- **secrets.md** - Describes agenix-based secret management with per-machine rekeying and runtime decryption.
- **build-system/** - Comprehensive build system documentation: custom stdenv (mold, ccache, hardening), R2-backed compiler cache, ephemeral Hetzner Cloud builders, and niks3 binary cache.
- **claude-architecture.md** - Comprehensive architecture reference for Claude Code integration: sandbox, credential proxy, skills, MCP servers, hooks, shell integration, configuration hierarchy, and secrets.
