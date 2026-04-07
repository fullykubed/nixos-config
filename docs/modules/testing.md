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

The dev shell (`nix develop`) installs [prek](https://github.com/j178/prek) as the git-hook runner. The hooks defined in `lib/devshell/default.nix` run automatically on `git commit`:

- **gitleaks** — scan staged changes for leaked secrets
- **nixfmt-rfc-style** — format all `.nix` files
- **statix** — lint `.nix` for anti-patterns
- **deadnix** — detect unused bindings in `.nix` files
- **check-bun-versions** — enforce matching versions across `package.json` files
- **check-bun-typecheck** — `tsc --noEmit` on changed `.ts` / `.tsx` files
- **check-bun-eslint** — ESLint on changed `.ts` / `.tsx` files

prek schedules hooks by priority tier; same-tier hooks run in parallel. `gitleaks` is a serial security gate, the nix-tier hooks (`nixfmt-rfc-style`, `statix`, `deadnix`) run concurrently, and the bun-tier hooks are staggered with `require_serial` to avoid races on `bun install`. See `lib/devshell/default.nix` for the exact tiering.

To run the formatter manually:

```bash
nix fmt
```

### Claude Stop hook

`.claude/hooks/stop-lint.sh` is a repo-scoped Claude Code `Stop` hook that runs `prek run --files …` over every changed file (staged, unstaged, untracked) at the end of every Claude turn, with a sha256 autofix-detection dance: if prek modifies files on the first run, the hook re-runs prek once to confirm the autofix resolved the issue. A turn cannot finish with lint/format failures in the working tree.

The hook depends on the `.pre-commit-config.yaml` symlink that the devshell `shellHook` installs; if Claude is launched outside `nix develop`, the hook exits 2 with a "run nix develop first" message.

## Tips

- When iterating on a single module, use the eval check (step 2) — it catches most errors in seconds.
- Build only when you need to verify that a derivation actually compiles (e.g. patches, overlays, custom packages).
- Use `--builders ""` to avoid spinning up remote builders during quick iteration.
