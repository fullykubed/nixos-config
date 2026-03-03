# Fix Type: Version Upgrades

When the current version of a package has a bug or vulnerability, upgrading to a newer version may fix the build.

## Error Signatures

No specific error signature — this is a fix strategy applied when other approaches aren't suitable and a newer version is known to fix the issue.

## Fix Strategies

### Inherit from Unstable

The simplest approach when `nixpkgs-unstable` has a newer version that fixes the issue:

```nix
# Package: Use unstable version - reason
inherit (final.unstable) package;
```

**Codebase examples:**
- `perl` — `inherit (final.unstable) perl;` (fixes CVE-2024-56406, heap buffer overflow)
- `jq` — `inherit (final.unstable) jq;` (fixes 3 CVEs in jq 1.7.1)

**Important**: When inheriting from unstable, check if other packages reference the stable version directly. You may need to override versioned aliases:

```nix
inherit (final.unstable) perl;
perl540 = final.unstable.perl;           # Replace versioned alias
perlPackages = final.unstable.perl5Packages;  # Replace package set
```

### Inherit from Unstable with Override

When you need the unstable version but with modifications (e.g., using patched dependencies):

```nix
# Package: Use unstable version with patched dependency
package = final.unstable.package.override {
  inherit (final) dependency;
};
```

**Codebase examples:**
- `gimp` — `final.unstable.gimp.override { gegl = ...; }` (unstable GIMP + patched OpenEXR)
- `imagemagick` — `(final.unstable.imagemagick.override { inherit (final) openexr; }).overrideAttrs ...` (unstable + patched dep + version pin)

### Version Bump

When a specific version fixes the issue and it's not yet in unstable:

```nix
# Package: Update to X.Y.Z - fixes build issue
package = prev.package.overrideAttrs (_old: rec {
  version = "X.Y.Z";
  src = prev.fetchFromGitHub {
    owner = "owner";
    repo = "repo";
    rev = "vX.Y.Z";    # or just version, or "refs/tags/vX.Y.Z"
    hash = "sha256-...";  # Use `nix hash to-sri --type sha256 $(nix-prefetch-url --unpack <url>)`
  };
});
```

**Codebase examples:**
- `openexr` — Version bump to 3.4.4 (+ added new dependency `openjph`)
- `imagemagick` — Version bump to 7.1.2-15
- `libcdio` — Version bump to 2.3.0

**Hash calculation**: If you don't know the hash, use a placeholder like `""` and the build error will tell you the correct hash. Or use:
```bash
nix-prefetch-url --unpack https://github.com/owner/repo/archive/vX.Y.Z.tar.gz
```

### Override Scope (for nested package sets)

For packages inside a scoped package set (e.g., dotnetCorePackages):

```nix
dotnetCorePackages = prev.dotnetCorePackages.overrideScope (
  _dotnetFinal: dotnetPrev: {
    vmr_8_0 = dotnetPrev.vmr_8_0.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./fixes/fix.patch
      ];
    });
  }
);
```

**Codebase example:**
- `dotnetCorePackages` — Override both `vmr_8_0` and `vmr_9_0` with FileVersion fix patch
