# BuildPackage Workflow

Build a single package to verify patches, overlays, or version changes work correctly. Supports building from both stable and unstable nixpkgs channels.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Determine Package and Channel

The user MUST specify a package name. If they haven't, ask for it.

| Situation | Channel argument |
|-----------|-----------------|
| User specified "stable" or didn't specify | `stable` (default) |
| User specified "unstable" | `unstable` |

### 2. Build the Package

```bash
nt-pkg <package> [stable|unstable] [hostname]
```

Hostname defaults to the current machine. Channel defaults to `stable`.

The script writes all build output to a temp log file and prints the path to stderr. Record this path for stall detection and error analysis.

### 3. Compare Versions (optional)

If the user is verifying a version change or comparing channels, evaluate the version:

```bash
nix eval .#<hostname>.stable.<package>.version
nix eval .#<hostname>.unstable.<package>.version
```

### 4. Report Results

- **Build succeeded**: Report success and the version (if evaluated).
- **Build failed**: Show the build log. Common failure causes:

  | Error | Likely cause |
  |-------|-------------|
  | Hash mismatch | Source hash changed upstream or patch doesn't apply |
  | Compilation error | Patch conflicts, missing dependencies, or hardening flag issue |
  | `attribute '...' missing` | Package name is wrong or doesn't exist in this channel |

## Guidelines

- Package names use the nixpkgs attribute path (e.g., `k9s`, `firefox`, `python3Packages.requests`).
- The `legacyPackages` flake output includes all overlays and patches from the config, so builds here test the exact same package that would be in the system.
- For packages with patches in `modules/patches/`, building here is the fastest way to verify the patch applies cleanly.
