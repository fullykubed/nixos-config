# Fix Type: Test Failures

Build-time test failures are the most common build error. Tests may fail due to sandbox restrictions, missing display servers, timing issues, or hardening flag interactions.

## Error Signatures

- `FAIL`, `FAILED`, `not ok`, `[FAIL]`, `[✗]`
- Non-zero exit from check phase
- `Test.*failed`
- `ERROR: test_` (Python)
- `test result: FAILED` (Rust)

## Fix Strategy Priority

Disabling tests should be an **absolute last resort**. Follow this order:

1. **Fix the root cause** — if the test exposes a real issue (missing dependency, wrong flag, incompatible version), fix that instead of skipping the test
2. **Disable only the specific failing test(s)** — use framework-specific mechanisms (see below) to skip the minimum number of tests while keeping the rest of the suite running
3. **Disable all tests** — only when the failures are clearly environment-related (sandbox restrictions, missing display server, network access) and affect the majority of the test suite

Always document *why* the test is being disabled and what environment limitation causes the failure. If the failure looks like a genuine bug rather than a sandbox issue, note that in the comment so it can be revisited.

## Fix Strategies

### Disable All Tests

Use **only** when most/all tests fail and the failures are environment-related (sandbox, display, network).

```nix
# Package: Disable tests - reason
package = prev.package.overrideAttrs (_old: {
  doCheck = false;
});
```

For install checks specifically:
```nix
package = prev.package.overrideAttrs (_old: {
  doInstallCheck = false;
});
```

**Codebase examples:**
- `texinfoInteractive` — 78/125 tests fail due to locale/encoding in sandbox
- `p11-kit` — 3 tests fail, needs PKCS#11 token/PIN infrastructure
- `git`/`gitMinimal`/`gitFull` — file:// protocol restrictions in sandbox
- `mss` (python-mss) — tests require X11 display unavailable in sandbox

### Disable Specific Tests (Meson)

```nix
# Package: Skip test-name - reason
package = prev.package.overrideAttrs (old: {
  mesonCheckFlags = (old.mesonCheckFlags or [ ]) ++ [
    "--exclude"
    "test-name"
  ];
});
```

**Codebase example:**
- `libadwaita` — Skip `test-dialog` which needs display + XDG_RUNTIME_DIR

### Disable Specific Tests (Python)

```nix
pythonXXXPackages = prev.pythonXXXPackages // {
  package = prev.pythonXXXPackages.package.overrideAttrs (old: {
    disabledTests = (old.disabledTests or [ ]) ++ [
      "test_name"
    ];
  });
};
```

**Codebase example:**
- `python312Packages.websockets` — Skip `test_writing_in_recv_events_fails` (race condition)

### Disable Specific Tests (Rust)

```nix
package = prev.package.overrideAttrs (old: {
  checkFlags = (old.checkFlags or [ ]) ++ [
    "--skip=test_name"
  ];
});
```

**Codebase example:**
- `deno` — Skip `node_unit_tests::os_test` (CPU count mismatch in sandbox)

### Disable Specific Tests (Autotools / Shell)

Replace test scripts with skip stubs (exit code 77 = skip in autotools):

```nix
package = prev.package.overrideAttrs (old: {
  preCheck = (old.preCheck or "") + ''
    echo '#!/bin/sh' > tests/test-name
    echo 'exit 77' >> tests/test-name
    chmod +x tests/test-name
  '';
});
```

Or use postPatch to write skip stubs:
```nix
package = prev.package.overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    echo 'exit 77' > tests/test-name.sh
  '';
});
```

**Codebase examples:**
- `libgcrypt` — Skip `t-kdf` test (SIGABRT from Argon2 + patched binutils interaction)
- `coreutils` — Skip `du/deref`, `du/inacc-dir`, `split/line-bytes` (hardening flag interactions)

### Disable Tests via Build System Flags

For Meson:
```nix
package = prev.package.overrideAttrs (old: {
  mesonFlags = (old.mesonFlags or [ ]) ++ [ "-Dtests=disabled" ];
});
```

For CMake:
```nix
package = prev.package.overrideAttrs (old: {
  cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DBUILD_TESTING=OFF" ];
});
```

**Codebase examples:**
- `waybar` — `-Dtests=disabled` (catch2 not found with custom stdenv)
- `gjs` — `-Dskip_gtk_tests=true` (GTK not found in sandbox)
- `onnxruntime` — `-Donnxruntime_BUILD_UNIT_TESTS=OFF` (CMake 4 GTest regression)
- `openjph` — `-DOJPH_BUILD_TESTS=OFF` (new package, tests not needed)

### Python Package Override Pattern

For packages nested in a Python package set, use the `packageOverrides` pattern:

```nix
python313 = prev.python313.override {
  packageOverrides = _pyfinal: pyprev: {
    package = pyprev.package.overrideAttrs {
      doInstallCheck = false;
    };
  };
};
```

**Codebase example:**
- `python313` / `mss` — Disable install checks for mss within python313 scope
