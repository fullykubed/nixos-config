# Preferred Executables

Some tools have been replaced by preferred alternatives in all scripted contexts. The original tools remain installed system-wide for interactive use, but scripts must use the replacement.

A lint hook in `.claude/hooks/lint.sh` enforces these rules on every shell script edit.

| Disallowed (in scripts) | Replacement | Notes |
|-------------------------|-------------|-------|
| `jq`                    | `jaq`       | Drop-in compatible for all flags used in this repo (`-r`, `-n`, `-c`, `-e`, `-R`, `-s`, `--arg`, `--argjson`). Also replaces `yq` for YAML via `--from yaml`. |
| `yq`                    | `jaq`       | Use `jaq --from yaml` for YAML input and `--to yaml` for YAML output. For markdown front-matter extraction, use the `extract-frontmatter` helper piped into `jaq --from yaml`. |
| `find`                  | `bfs`       | Breadth-first search — drop-in replacement for GNU find with identical flags. Faster for common cases since shallow matches are found sooner. Also aliased globally via the `modules/patches/findutils/` overlay. |

## Nix usage

In `writeShellApplication` derivations, use `pkgs.jaq` in `runtimeInputs`. In `substitute`/`mkDerivation` scripts, use `"${pkgs.jaq}/bin/jaq"` for store-path injection.

```nix
pkgs.writeShellApplication {
  name = "my-tool";
  runtimeInputs = [ pkgs.jaq ];
  text = builtins.readFile ./scripts/my-tool.sh;
};
```
