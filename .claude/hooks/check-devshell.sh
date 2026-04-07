#!/usr/bin/env bash
# SessionStart hook: verify Claude Code is running inside this repo's
# `nix develop` shell. The PostToolUse (lint.sh) and Stop (stop-lint.sh)
# hooks both shell out to prek, which in turn invokes bun, nixfmt,
# statix, deadnix, eslint, tsc, gitleaks, etc. All of those come from
# the devshell; launching claude outside it means every lint/typecheck
# hook fails with "command not found" on the first edit.
#
# Exit 2 blocks the session with a user-visible stderr message per
# Claude Code's SessionStart hook semantics
# (https://code.claude.com/docs/en/hooks.md).

set -euo pipefail

missing=()

if [[ -z "${IN_NIX_SHELL:-}" ]]; then
  # shellcheck disable=SC2016  # literal '$IN_NIX_SHELL' in user-facing message
  missing+=('$IN_NIX_SHELL is unset (not inside any nix-shell / nix develop)')
fi

# Sanity-check that the active shell is *this* repo's devshell by
# probing for tools that only our devshell puts on PATH. Catches the
# "I'm in some other nix develop shell" case. Note: the formatter
# binary is `treefmt` (our `nixfmt` variable in lib/devshell is a
# treefmt.withConfig wrapper, not the nixfmt binary itself).
for tool in prek bun bun2nix treefmt statix deadnix; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing+=("'$tool' not on PATH")
  fi
done

if [[ ${#missing[@]} -eq 0 ]]; then
  exit 0
fi

cat >&2 <<EOF
Claude Code is not running inside this repo's nix develop shell.

Missing:
$(printf '  - %s\n' "${missing[@]}")

The PostToolUse and Stop hooks depend on the devshell toolchain (bun,
prek, treefmt, statix, deadnix, eslint, typescript). Running claude
outside the devshell means every lint/typecheck hook will fail with
"command not found" on the first edit.

To fix, exit this Claude session and relaunch from inside the shell:

    nix develop --command claude

or, to stay in an interactive shell first:

    nix develop
    claude

EOF

exit 2
