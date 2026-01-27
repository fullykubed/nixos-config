# CLAUDE.md

Guidance for Claude Code when working with this NixOS configuration repository.

## Documentation

- [README.md](README.md) - Repository overview, philosophy, and features
- [docs/commands.md](docs/commands.md) - System rebuild and development commands
- [docs/deployment.md](docs/deployment.md) - How the deployment script works
- [docs/adding-modules.md](docs/adding-modules.md) - Creating new configuration modules
- [docs/adding-machines.md](docs/adding-machines.md) - Configuring new systems
- [docs/secrets.md](docs/secrets.md) - Secret management with agenix
- [modules/common/README.md](modules/common/README.md) - Comprehensive module reference (60+ modules)

## Security & Vulnerability Management

### Vulnix Scanner
A systemd service runs daily at 2 AM to scan for CVE vulnerabilities:
- Service: `vulnix-scanner.service`
- Timer: `vulnix-scanner.timer`
- Scans both system packages and home-manager profile

```bash
# Manual scan
vulnix --system

# Check service status
systemctl status vulnix-scanner.timer
```

### Applying Security Patches
Security patches for CVEs not yet in nixpkgs are managed in the `patches/` directory:
- `patches/default.nix`: Overlay that applies all patches
- `patches/CVE-*.patch`: Individual patch files

To add a new CVE fix, see `.claude/skills/resolve-cve.md` for the full workflow.

### Patch Structure
```
patches/
├── default.nix                    # Overlay applying all patches
└── CVE-XXXX-XXXXX-<pkg>.patch    # Patch files
```

## Important Notes

- Unstable packages available via `pkgs.unstable`

