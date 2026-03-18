# Scripts and Utilities

## Where scripts live

Scripts belong inside the module they support. If a script is part of the `git` module, it goes in `modules/common/git/scripts/`, not in a central scripts directory.

The one exception is `modules/common/scripts/` — a catch-all for general-purpose scripts (e.g. `un.sh` for rebuilds). Any `.sh` file placed in `modules/common/scripts/scripts/` is automatically installed on the PATH with the `.sh` extension stripped (e.g. `un.sh` becomes `un`).

## Allowed languages

All scripts and tools in this repo must be written in either **bash** or **TypeScript (Bun)**. No other languages or runtimes (Python, Ruby, Node, etc.) should be used for custom scripts.

- [Shell Script Conventions](shell-scripts.md) — bash style, `writeShellApplication`, drop-in scripts
- [Preferred Executables](preferred-executables.md) — tools replaced by preferred alternatives in scripted contexts
- [Bun Tools](bun-tools.md) — TypeScript tool setup with `bun2nix`
