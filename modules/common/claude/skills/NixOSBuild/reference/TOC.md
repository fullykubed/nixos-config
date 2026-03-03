# reference/

Error-specific handler docs and build tooling reference used by the build-fix loop.

- `eval-attr-missing.md` — Handler for attribute-not-found and undefined-variable errors (renamed packages, changed paths, typos).
- `eval-type-error.md` — Handler for value type mismatches and coercion failures.
- `eval-infinite-recursion.md` — Handler for circular references in overlays, imports, or recursiveUpdate.
- `eval-assertion.md` — Handler for failed assert statements and option assertions.
- `eval-syntax.md` — Handler for invalid Nix language syntax.
- `compilation-errors.md` — C/C++ compilation error patterns and fixes (missing includes, libs, ABI issues).
- `hash-mismatch.md` — Hash mismatch errors during fetch phases; covers updating hashes and checking URLs.
- `missing-dependencies.md` — Missing build/runtime dependency resolution and package discovery.
- `test-failures.md` — Build-time test failures; covers per-framework test disabling and doCheck settings.
- `version-upgrades.md` — Version upgrade issues including API breaks and config format changes.
- `source-patches.md` — Applying source patches for unfixed bugs in nixpkgs packages.
- `builder-issues.md` — Troubleshooting builder problems (cache issues, builder crashes, missing deps).
- `build-flags.md` — Common nix build flags and options for build tuning.
- `build-unknown.md` — Fallback handler for unknown or unclassified build errors.
- `report-formats.md` — Nix build error output format documentation for parsing and interpretation.
- `research.md` — Guidance for using web search and deep research within the build-fix workflow.
- `cli-tools.md` — CLI tools available during builds (nix eval, nix build, grep, etc.).
