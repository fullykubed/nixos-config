#!/usr/bin/env bash
# test-completions: Spin up an ephemeral zsh with j tab-completion active.
#
# Generates a fresh carapace spec from the live registry, installs it under
# a temp XDG_CONFIG_HOME (working around the read-only ~/.config ZFS dataset),
# then opens an interactive zsh with carapace sourced.
#
# Usage: bun scripts/test-completions.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

info()  { printf ':: %s\n' "$*" >&2; }
error() { printf ':: Error: %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------------------------
# Temp workspace — cleaned up on exit
# ------------------------------------------------------------------------------

TMPDIR="$(mktemp -d /tmp/j-completion-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# ------------------------------------------------------------------------------
# Generate carapace spec from the live registry
# ------------------------------------------------------------------------------

SPEC_DIR="$TMPDIR/carapace/specs"
mkdir -p "$SPEC_DIR"

info "Generating carapace spec from registry..."
(cd "$CLI_DIR" && bun scripts/generate-completions.ts) > "$SPEC_DIR/j.yaml" \
  || error "Spec generation failed. Is node_modules installed? (bun install)"
info "Spec ready."

# ------------------------------------------------------------------------------
# Create a j shim so the binary is available even before nixos-rebuild
# ------------------------------------------------------------------------------

mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/j" <<EOF
#!/usr/bin/env bash
exec bun "$CLI_DIR/src/main.ts" "\$@"
EOF
chmod +x "$TMPDIR/bin/j"

# ------------------------------------------------------------------------------
# Write a minimal .zshrc: inherits PATH, adds shim, enables carapace
# ------------------------------------------------------------------------------

# Unquoted heredoc so $TMPDIR expands, but escape $PATH so it inherits
# the runtime PATH (which includes carapace from `nix shell`)
cat > "$TMPDIR/.zshrc" <<EOF
export PATH="$TMPDIR/bin:\$PATH"
autoload -Uz compinit && compinit
source <(carapace _carapace zsh)
print -P ""
print -P "%F{green}:: j completion test session%f"
print -P "%F{244}:: Spec generated from live registry%f"
print -P "%F{244}:: Try:%f %Bj builders <TAB>%b"
print -P "%F{244}::      %f %Bj builders check --<TAB>%b"
print -P "%F{244}::      %f %Bj builders check <TAB>%b   (live builder names, requires running builders)"
print -P "%F{244}:: exit%f to return"
print -P ""
EOF

# ------------------------------------------------------------------------------
# Launch the test shell
# ------------------------------------------------------------------------------

info "Launching test shell..."
ZDOTDIR="$TMPDIR" XDG_CONFIG_HOME="$TMPDIR" \
  nix shell nixpkgs#carapace --command zsh
