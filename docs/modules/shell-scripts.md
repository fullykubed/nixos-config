# Shell Script Conventions

## Creating shell scripts

### Drop-in scripts (simplest)

For standalone scripts that don't need Nix dependencies, add a `.sh` file to `modules/common/scripts/scripts/`:

It will be available as `my-tool` on the PATH after rebuilding.

### writeShellApplication (preferred)

Always use `writeShellApplication` for scripts scoped to a module. It sets `set -euo pipefail` automatically, validates the script with `shellcheck`, and lets you declare runtime dependencies explicitly:

```nix
{ config, pkgs, ... }:
let
  myScript = pkgs.writeShellApplication {
    name = "my-tool";
    runtimeInputs = [
      pkgs.jq
      pkgs.curl
    ];
    text = builtins.readFile ./scripts/my-tool.sh;
  };
in {
  home-manager.users.${config.username} = {
    home.packages = [ myScript ];
  };
}
```

For scripts with no special dependencies, `runtimeInputs` can be omitted:

```nix
myScript = pkgs.writeShellApplication {
  name = "my-tool";
  text = ''
    echo "hello from $1"
  '';
};
```

Or read from a file to keep Nix and bash separate:

```nix
myScript = pkgs.writeShellApplication {
  name = "my-tool";
  text = builtins.readFile ./scripts/my-tool.sh;
};
```

### Which approach to use

| Scenario | Approach |
|----------|----------|
| Simple standalone script, no dependencies | Drop-in `.sh` file |
| Script scoped to a module | `writeShellApplication` |
| Complex tool with dependencies / TypeScript | Bun + `bun2nix` (see [Bun Tools](bun-tools.md)) |

## Basics

- Use `#!/usr/bin/env bash` as the shebang
- Use `set -euo pipefail` for scripts that should fail on errors. At minimum use `set -o pipefail`
- Add a short comment at the top explaining what the script does

```bash
#!/usr/bin/env bash

# mnemonic: [S]earch $[P]ATH
# Fuzzy searches PATH for a given file name and shows the location

set -euo pipefail
```

## Naming

Scripts should have short, memorable names. Use mnemonics where possible and document them in a comment:

- `un` — **u**pdate **n**ixos
- `sp` — **s**earch **P**ATH
- `pk` — **p**rocess **k**ill
- `ssj` — **s**creen**s**hot **j**peg

The `.sh` extension is used in the source file but stripped when installed to the PATH.

## Arguments and defaults

Use parameter defaults for optional arguments:

```bash
COMMAND=${1:-'up'}          # default to 'up' if no arg given
BOOT_NUM="${1:-0}"          # default to current boot
SIGNAL="${1:-15}"           # default to SIGTERM
```

## Help text

Scripts with multiple options should include a `show_help` function and respond to `-h`/`--help`:

```bash
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME

show_help() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Description of what this script does.

Options:
  -f, --flag        Description of flag
  -v, --value N     Description of value option
  -h, --help        Show this help message

Examples:
  $SCRIPT_NAME               # Default behavior
  $SCRIPT_NAME -f -v 3       # With options
EOF
}
```

## Argument parsing

Use a `while`/`case` loop for option parsing:

```bash
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -f|--flag)    FLAG=true ;;
      -v|--value)   shift; VALUE="$1" ;;
      -h|--help)    show_help; exit 0 ;;
      *)            error "Unknown option: $1" ;;
    esac
    shift
  done
}
```

## Logging and output

Standard out is reserved for data meant to be piped into other programs. All logging, status messages, and informational output must go to standard error. This ensures scripts compose cleanly in pipelines.

```bash
info()  { echo ":: $*" >&2; }
warn()  { echo ":: Warning: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }
```

Only write to stdout when producing output that another program will consume:

```bash
# Good — data to stdout, status to stderr
info "Resolving snapshot..."
snapshot_id=$(hcloud image list -o json | jq -r '.id')
echo "$snapshot_id"    # piped to the next command

# Bad — mixing status messages into stdout
echo "Resolving snapshot..."    # breaks pipelines
echo "$snapshot_id"
```

## Exit codes and error handling

With `set -e`, any command that returns a non-zero exit code will terminate the script. When you need to capture an exit code without exiting, use `|| true` or an `if` block:

```bash
# Capture exit code without triggering set -e
nix build .#foo 2>&1; exit_code=$?

# Or use if to branch on success/failure
if nix build .#foo 2>/dev/null; then
  info "Build succeeded"
else
  info "Build failed"
fi
```

### Pipelines and pipefail

With `set -o pipefail`, a pipeline fails if **any** command in it fails — not just the last one. This is important because without it, errors in early stages are silently swallowed:

```bash
# Without pipefail: exits 0 even if nix build fails
nix build .#foo 2>&1 | tee build.log

# With pipefail: exits non-zero if nix build fails
set -o pipefail
nix build .#foo 2>&1 | tee build.log
```

When you intentionally want to ignore a pipeline failure, be explicit:

```bash
# Allow the build to fail but still capture output
nix build .#foo 2>&1 | tee build.log || true
```

Use `${PIPESTATUS[@]}` to inspect individual exit codes from a pipeline:

```bash
nix build .#foo 2>&1 | nom --json
build_exit=${PIPESTATUS[0]}
if [[ $build_exit -ne 0 ]]; then
  error "Build failed with exit code $build_exit"
fi
```

## Sections

Longer scripts should use section dividers for readability:

```bash
# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

readonly CONFIG_DIR="/etc/nixos"

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

do_something() {
  # ...
}
```

## Cleanup

Use `trap` for temporary file cleanup:

```bash
TMP_FILE=$(mktemp)
cleanup() { rm -f "$TMP_FILE"; }
trap cleanup EXIT
```

## Injecting Nix values with substitute

When a script needs store paths or config values from Nix, use `substitute` to replace `@placeholder@` tokens at build time:

```nix
pkgs.stdenv.mkDerivation {
  # ...
  installPhase = ''
    mkdir -p $out/bin
    substitute $src/my-tool.sh $out/bin/my-tool \
      --replace-fail "@hostname@" "${pkgs.hostname}/bin/hostname" \
      --replace-fail "@home@" "${config.homeDir}"
    chmod +x $out/bin/my-tool
  '';
}
```

In the script, use the tokens as placeholders:

```bash
#!/usr/bin/env bash
hostname=$(@hostname@)
echo "Home is @home@"
```

## Running as root

When a script needs root, re-exec with `doas` early rather than sprinkling `doas` throughout:

```bash
if [[ $EUID -ne 0 ]]; then
  exec doas "$0" "$@"
fi
```

Use `DOAS_USER` to run commands as the original user when needed:

```bash
as_user() {
  if [[ -n "${DOAS_USER:-}" ]]; then
    runuser -u "$DOAS_USER" -- "$@"
  else
    "$@"
  fi
}
```
