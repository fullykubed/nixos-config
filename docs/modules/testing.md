# Testing Changes

## Fastest feedback loop

From fastest to slowest:

### 1. Syntax check (instant)

Catch syntax errors without evaluating anything:

```bash
nix-instantiate --parse modules/common/my-module/default.nix > /dev/null
```

### 2. Eval check (seconds)

Verify the full configuration evaluates without errors:

```bash
nix eval --impure .#nixosConfigurations.<hostname>.config.system.build.toplevel 2>&1 | head -50
```

Replace `<hostname>` with `fullykubed-tower` or `fullykubed-mini-pc`.

### 3. Dry build (seconds to minutes)

Check that everything evaluates and see what would be built, without actually building:

```bash
nix build --dry-run --impure .#nixosConfigurations.<hostname>.config.system.build.toplevel
```

### 4. Build a single package (seconds to minutes -- sometimes an hour+ for large packages)

Build or compare an individual package without building the full system:

```bash
# Build a package from stable nixpkgs (with overlays/patches applied)
nix build .#fullykubed-tower.stable.k9s --no-link

# Build a package from unstable nixpkgs
nix build .#fullykubed-tower.unstable.k9s --no-link

# Compare versions between stable and unstable
nix eval .#fullykubed-tower.stable.k9s.version
nix eval .#fullykubed-tower.unstable.k9s.version
```

Replace `fullykubed-tower` with any hostname. Useful for verifying patches, overlays, or checking package versions.

### 5. Build a single config option

Build any config option that resolves to a derivation:

```bash
# Build just the kernel
nix build .#nixosConfigurations.<hostname>.config.boot.kernelPackages.kernel --no-link

# Build the etc file tree
nix build .#nixosConfigurations.<hostname>.config.system.build.etc --no-link
```

Use `nix eval` for non-derivation options (strings, lists, etc.).

### 6. Build without switching (minutes to hours)

Build the full system derivation to confirm everything compiles:

```bash
nix build --no-link --impure .#nixosConfigurations.<hostname>.config.system.build.toplevel
```

Add `--builders ""` to build locally without remote builders.

### 7. Build and switch

Deploy the configuration to the running system:

```bash
un
```

See [deployment.md](../deployment.md) for options.

## Pre-commit hooks

The dev shell (`nix develop`) installs pre-commit hooks that run automatically on `git commit`:

- **nixfmt-rfc-style** — format all `.nix` files
- **statix** — lint for anti-patterns
- **deadnix** — detect unused bindings
- **gitleaks** — scan for leaked secrets

To run the formatter manually:

```bash
nix fmt
```

## Tips

- When iterating on a single module, use the eval check (step 2) — it catches most errors in seconds.
- Build only when you need to verify that a derivation actually compiles (e.g. patches, overlays, custom packages).
- Use `--builders ""` to avoid spinning up remote builders during quick iteration.
