# Fix Type: BUILD_UNKNOWN

The derivation build failed but the error doesn't match any known category (test failure, compilation error, missing dependency, build flag error, or resource issue).

## Approach

1. **Read the full derivation log** to understand what phase failed:
   ```bash
   nix log <derivation-path> 2>&1 | tail -n 500
   ```

2. **Identify the build phase** — Nix builds run in phases. Determine which one failed:
   - `unpackPhase` — source extraction failed (corrupt archive, wrong hash)
   - `patchPhase` — a patch failed to apply (offset, fuzz, context mismatch)
   - `configurePhase` — configuration script failed (not a known build system error)
   - `buildPhase` — the build command failed (not a known compilation error)
   - `installPhase` — installation failed (missing files, permission issues, path issues)
   - `fixupPhase` — post-install fixups failed (rpath, shebang patching)
   - `checkPhase` — tests failed (but didn't match known test failure patterns)

3. **Search for the error online** — read `reference/research.md` and follow the search strategy.

## Common Fixes

### Patch failed to apply

The upstream source changed and an existing patch no longer applies cleanly:
- Regenerate the patch against the new source
- Adjust fuzz/offset or rewrite the patch
- Check if the patch is still needed (the upstream fix may have been merged)

See `reference/source-patches.md` for patch creation and application patterns.

### Install phase failure

Files expected by the install phase are missing or in the wrong location:
```nix
overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    # Fix missing file or wrong path
    mkdir -p $out/share/foo
    cp -r bar $out/share/foo/
  '';
})
```

### Fixup phase failure

Nix's automatic fixup (rpath patching, shebang rewriting) failed:
```nix
overrideAttrs (old: {
  dontFixup = true;  # skip fixup entirely (use sparingly)
  # or fix specific issues:
  postFixup = (old.postFixup or "") + ''
    patchelf --set-rpath "${lib.makeLibraryPath [ dep1 dep2 ]}" $out/bin/foo
  '';
})
```

### Hook or wrapper failure

A setup hook or wrapper script failed:
```nix
overrideAttrs (old: {
  dontWrapGApps = true;  # skip GLib wrapping
  dontWrapQtApps = true; # skip Qt wrapping
})
```

## When to Give Up

If the error is completely opaque after reading the full log and 2-3 online searches, report the failure with the raw log output so the user can investigate manually.
