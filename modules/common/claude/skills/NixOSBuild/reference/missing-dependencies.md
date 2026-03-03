# Fix Type: Missing Dependencies

Build failures caused by missing build-time or runtime dependencies.

## Error Signatures

- `No such file or directory` (missing header or tool)
- `Package 'X' not found` (pkg-config)
- `cannot find -lX` (missing library)
- `command not found` (missing build tool)
- `CMake Error ... could not find ...`

## Fix Strategies

### Add Build-Time Dependency

For missing tools, compilers, or generators needed during the build:

```nix
# Package: Add missing build dependency
# Build error: X not found during configure/build
package = prev.package.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.dependency ];
});
```

**Codebase example:**
- `binutils-unwrapped` — Add `prev.flex` to `nativeBuildInputs`

### Add Runtime Library Dependency

For missing libraries needed at link time or runtime:

```nix
# Package: Add missing runtime library
# Build error: cannot find -lX / Package 'X' not found
package = prev.package.overrideAttrs (old: {
  buildInputs = (old.buildInputs or [ ]) ++ [ prev.library ];
});
```

**Codebase example:**
- `openexr` — Add `final.openjph` to `buildInputs` (JPEG2000 HTJ2K support)

### Replace Dependency

When a dependency needs to be swapped (e.g., abandoned package for maintained alternative):

```nix
package = prev.package.overrideAttrs (old: {
  nativeBuildInputs = (builtins.filter (x: (x.pname or x.name or "") != "old-dep") old.nativeBuildInputs)
    ++ [ final.new-dep ];
});
```

**Codebase example:**
- yasm → nasm migration: `replaceYasmWithNasm` helper used for `libvpx`, `libaom`, `xvidcore`, `libass`

### Override Transitive Dependency

When a transitive dependency needs to be updated but isn't directly a build input:

```nix
# Package: Use patched dependency
package = prev.package.override {
  inherit (final) dependency;
};
```

**Codebase examples:**
- `gegl` — `override { openexr_2 = final.openexr; }` (use modern OpenEXR)
- `libavif` — `override { inherit (final) libaom; }` (use nasm-based libaom)
- `libheif` — `override { inherit (final) libaom; }` (same reason)
- `gd` — `override { inherit (final) libavif; }` (use fixed libavif)
- `libgphoto2` — `override { inherit (final) gd; }` (propagate fix)

### Force Rebuild with Fixed Dependency

When a package needs to use a patched version of a dependency but `override` doesn't reach it:

```nix
# Package: Force rebuild with patched dependency
package = prev.package.overrideAttrs (old: {
  buildInputs = map (
    input: if (input.pname or "") == "dep-name" then final.dep-name else input
  ) old.buildInputs;
});
```

**Codebase example:**
- `gvfs` — Map `libcdio` in buildInputs to use version 2.3.0
