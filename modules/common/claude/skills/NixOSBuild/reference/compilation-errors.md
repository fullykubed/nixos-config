# Fix Type: Compilation Errors

Compilation errors occur when a package's source code fails to compile. Causes include hardening flag interactions, missing headers, uninitialized variables, and incompatible code.

## Error Signatures

- `error:` from gcc/g++/clang
- `fatal error: ... No such file or directory` (missing header)
- `-Werror=maybe-uninitialized`, `-Werror=uninitialized`
- `undefined reference to` (linker error)
- `ld: cannot find -l...` (missing library)

## Fix Strategies

### Disable Hardening Flag

When hardening flags (added globally in this repo's stdenv) cause compilation failures.

```nix
# Package: Disable trivialautovarinit - reason
package = prev.package.overrideAttrs (old: {
  hardeningDisable = (old.hardeningDisable or [ ]) ++ [ "trivialautovarinit" ];
});
```

Available hardening flags in this repo:
- `trivialautovarinit` — Zero-init automatic variables (`-ftrivial-auto-var-init=pattern`)

Common failure pattern: VLA (variable-length array) incompatibility with `__builtin_clear_padding`.

**Codebase example:**
- `lttng-ust` — VLA in tracepoint macros incompatible with trivialautovarinit

### Fix Source with postPatch

For simple source fixes like initializing variables to silence `-Werror`:

```nix
# Package: Initialize variable to fix -Werror=maybe-uninitialized
package = prev.package.overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    sed -i 's/type var;/type var = 0;/' path/to/file.c
  '';
});
```

**Codebase examples:**
- `sway-unwrapped` — Initialize `pid` variable: `sed -i 's/pid_t pid;/pid_t pid = 0;/' sway/tree/view.c`
- `libaom` — Fix cmake bug in nasm detection via `sed` on `aom_optimization.cmake`

### Add Missing Header/Library

When compilation fails because a header or library isn't found:

```nix
# Package: Add missing build dependency
package = prev.package.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.dependency ];
});
```

Or for runtime libraries:
```nix
package = prev.package.overrideAttrs (old: {
  buildInputs = (old.buildInputs or [ ]) ++ [ prev.dependency ];
});
```

**Codebase example:**
- `binutils-unwrapped` — Add `prev.flex` to `nativeBuildInputs`
- `openexr` — Add `final.openjph` to `buildInputs`

### Create Source Patch

For non-trivial source changes that can't be done with `sed`:

1. Create patch file in `patches/fixes/<package>-<issue>.patch`
2. Add overlay entry:

```nix
# Package: Fix build error via source patch
# Build error: brief description
package = prev.package.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./fixes/<package>-<issue>.patch
  ];
});
```

**Codebase example:**
- `assimp` — `./fixes/assimp-fix-uninitialized-shadingMode.patch` (fix test code triggering -Werror=maybe-uninitialized)

### Exclude Package from Global Hardening

For packages that fundamentally can't work with hardening flags (compilers, assemblers):

Add the package name to `hardeningExcludedPackages` list in `patches/default.nix`. This gives it only default nixpkgs hardening (stackprotector, fortify, pie, relro).

**Codebase examples:** gcc, clang, llvm, binutils, nasm, yasm, dejagnu
