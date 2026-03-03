# Fix Type: Build System Configuration

Errors from CMake, Meson, autotools, or other build systems failing to configure properly.

## Error Signatures

- `CMake Error at ...`
- `ERROR:` from meson
- `meson.build:` errors
- `configure: error:`
- `configuration failed`

## Fix Strategies

### Disable Feature via Meson

```nix
# Package: Disable feature - reason
package = prev.package.overrideAttrs (old: {
  mesonFlags = (old.mesonFlags or [ ]) ++ [ "-Dfeature=disabled" ];
});
```

**Codebase examples:**
- `waybar` — `-Dtests=disabled` (catch2 not found with custom stdenv)
- `gjs` — `-Dskip_gtk_tests=true` (GTK not found in sandbox)

### Disable Feature via CMake

```nix
# Package: Disable feature - reason
package = prev.package.overrideAttrs (old: {
  cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DBUILD_FEATURE=OFF" ];
});
```

**Codebase examples:**
- `onnxruntime` — `-Donnxruntime_BUILD_UNIT_TESTS=OFF` (CMake 4 GTest regression)
- `openjph` — `-DOJPH_BUILD_TESTS=OFF`, `-DOJPH_BUILD_EXECUTABLES=OFF`

### Adjust Configure Flags (Autotools)

```nix
package = prev.package.overrideAttrs (old: {
  configureFlags = (old.configureFlags or [ ]) ++ [ "--disable-feature" ];
});
```

Or replace a flag:
```nix
package = prev.package.overrideAttrs (old: {
  configureFlags = map (flag: if flag == "--old-flag" then "--new-flag" else flag) old.configureFlags;
});
```

**Codebase example:**
- `libvpx` — Replace `--as=yasm` with `--as=nasm` in configureFlags
