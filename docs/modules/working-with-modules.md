# Working with Modules

## Where to put it

- `modules/common/` -- modules imported unconditionally for every machine. This is where most modules live.
- `modules/utility/` -- standalone helpers that are imported selectively (e.g. by device files or image definitions), not by `modules/default.nix`.
- `modules/patches/` -- per-package overlay modules for CVE patches and build fixes.

## Creating a new module

See [Creating a Module](creating-a-module.md).

## Organization

Each module owns a single domain (e.g. `browser/`, `git/`, `messaging/`). Everything related to that domain should be co-located inside the module:

- **Packages** — install via `home.packages` or `environment.systemPackages`
- **Program configuration** — `programs.*` settings, config files via `xdg.configFile`
- **Shell aliases** — `programs.zsh.shellAliases`
- **Desktop entries** — `xdg.desktopEntries`
- **Secrets** — `age.secrets` declarations
- **Helper scripts** — shell scripts in a `scripts/` subdirectory
- **Custom options** — `options.*` declarations consumed by device files

Don't scatter related config across multiple modules. For example, the `git/` module contains git config, SSH keys, shell aliases, lazygit settings, and helper scripts — all in one place.

When a module grows large, split it into sub-components with their own directories. The parent `default.nix` imports them:

```nix
# modules/common/git/default.nix
{
  imports = [
    ./lazygit
    ./lazyworktree
  ];

  # Main git configuration here...
}
```

## Guidelines

These must be followed when writing modules:

- [Home Manager usage](home-manager.md) -- use Home Manager for packages and user config, not system-level options
- [Working with packages](working-with-packages.md) -- unstable channel, external packages, and centralized versioning
- [Custom options](custom-options.md) -- use options for per-machine differences, don't hardcode values
- [Theming](theming.md) -- use Stylix base16 colors, don't hardcode colors or fonts
- [Secrets](../secrets.md) -- use agenix for any credentials, tokens, or keys
- [Scripts](scripts.md) -- creating shell scripts and CLI utilities
- [Testing](testing.md) -- verify changes quickly before deploying
