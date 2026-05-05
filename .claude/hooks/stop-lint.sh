#!/usr/bin/env bash
# Stop hook: at the end of every Claude turn, run prek over every changed
# file in the worktree. Mirrors Panfactum/stack/.claude/hooks/stop-lint.sh.
#
# prek exits non-zero whenever a hook autofixes a file, even when there is
# no real error. To distinguish autofix from a true failure, snapshot the
# file contents before the run; if prek fails but the files are unchanged,
# it's a real error and we exit 2. If files were modified by prek, re-run
# once to confirm whether the autofix resolved everything.

set -euo pipefail

if [[ -n "${CLAUDE_SKIP_LINT:-}" ]]; then
  echo "stop-lint: skipping (CLAUDE_SKIP_LINT is set)" >&2
  exit 0
fi

if [[ -z "${CLAUDE_PROJECT_DIR:-}" ]]; then
  echo "stop-lint: CLAUDE_PROJECT_DIR is not set" >&2
  exit 2
fi

cd "$CLAUDE_PROJECT_DIR"

if [[ ! -e "$CLAUDE_PROJECT_DIR/.pre-commit-config.yaml" ]]; then
  echo "stop-lint: .pre-commit-config.yaml not found in $CLAUDE_PROJECT_DIR; run 'nix develop' in this worktree first" >&2
  exit 2
fi

# Collect all changed files (staged, unstaged, and untracked).
# --diff-filter=d excludes deletions so we don't pass non-existent paths to prek.
mapfile -t FILES < <(
  {
    git diff --name-only --diff-filter=d HEAD 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null || true
  } | sort -u
)

if [[ ${#FILES[@]} -eq 0 ]]; then
  exit 0
fi

hash_files() {
  sha256sum -- "${FILES[@]}" 2>/dev/null | sha256sum
}

before=$(hash_files)
if ! prek run --no-progress -c "$CLAUDE_PROJECT_DIR/.pre-commit-config.yaml" --files "${FILES[@]}" 1>&2; then
  after=$(hash_files)
  if [[ "$before" == "$after" ]]; then
    exit 2
  fi
  prek run --no-progress -c "$CLAUDE_PROJECT_DIR/.pre-commit-config.yaml" --files "${FILES[@]}" 1>&2 || exit 2
fi
