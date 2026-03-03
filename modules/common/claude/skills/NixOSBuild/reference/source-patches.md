# Fix Type: Source Patches

When a package needs source-level changes that are too complex for `postPatch` sed commands.

## When to Use

- Multi-line source changes
- Changes to multiple files
- Backporting upstream commits
- Changes requiring careful context matching

## Creating a Patch File

### From an Upstream Commit

```bash
# Download patch from GitHub commit
curl -L https://github.com/owner/repo/commit/<sha>.patch > patches/fixes/<package>-<issue>.patch
```

### From a Git Diff

```bash
# Generate patch from local changes
cd /tmp && git clone <repo-url> && cd <repo>
# Make changes...
git diff > /path/to/nixos-config/patches/fixes/<package>-<issue>.patch
```

### Patch Naming Convention

- CVE patches: `patches/cves/CVE-XXXX-XXXXX.patch` (CVE ID only)
- Build fix patches: `patches/fixes/<package>-<description>.patch`
- Multiple patches for same issue: append `-2`, `-3`, etc.

## Applying Patches

### Basic Pattern

```nix
# Package: Fix description
# Error: what failed
# Upstream: link to issue/PR/commit
package = prev.package.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./fixes/<package>-<issue>.patch
  ];
});
```

### Multiple Patches

```nix
package = prev.package.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./cves/CVE-XXXX-XXXXX.patch
    ./cves/CVE-XXXX-XXXXX-2.patch
    ./fixes/<package>-<other-fix>.patch
  ];
});
```

**Codebase examples:**
- `avahi` — 3 CVE patches
- `busybox` — 3 CVE patches (2 for same CVE)
- `fluidsynth` — 2 patches for 1 CVE
- `assimp` — 1 CVE patch + 1 build fix patch
- `binutils-unwrapped` — 3 CVE patches + added dependency

## Comment Style

Every patch entry must have a comment block:

```nix
# Package: Brief description of what the patch fixes
# CVE-XXXX-XXXXX (CVSS X.X Severity): One-line description
# See: https://nvd.nist.gov/vuln/detail/CVE-XXXX-XXXXX
```

Or for non-CVE fixes:
```nix
# Package: Brief description of the build fix
# Build error: what failed and why
# Upstream: link to upstream issue/PR if available
```
