# Creating a Module

## Choose the right location

**`modules/common/`** -- Most modules go here. These are imported unconditionally for every machine via `modules/default.nix`. Use this for anything that should be present on all systems: applications, services, shell config, desktop environment settings, etc.

**`modules/utility/`** -- Standalone helpers imported selectively by specific consumers (e.g. `flake.nix`, device files, or image definitions). These are *not* listed in `modules/default.nix`. Use this when a module is only needed in certain contexts — for example, shared binary cache settings used by both local machines and Hetzner disk images.

**`modules/patches/`** -- Per-package overlay modules for CVE patches and build fixes. Each subdirectory targets one package and applies patches via `nixpkgs.overlays`. These are imported collectively by `modules/patches/default.nix`.

## Before creating a new module

Check whether an existing module already covers your use case. Review the TOC files for a quick summary of what exists:

- `modules/common/TOC.md` -- all common modules
- `modules/utility/TOC.md` -- utility modules
- `modules/patches/TOC.md` -- patch modules

If related functionality already exists, extend that module rather than creating a new one.

## Steps

For a common module:

1. Create a directory under `modules/common/` with a `default.nix`.

2. Add the import to `modules/default.nix`:

```nix
imports = [
  # ...existing imports...
  ./common/my-module
];
```

For a utility module, create a `.nix` file in `modules/utility/` and import it directly where needed.

For a patch module, create a directory under `modules/patches/` and add it to `modules/patches/default.nix`.

## Next steps

Follow the guidelines in [Working with Modules](working-with-modules.md).
