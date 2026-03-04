#!/usr/bin/env bash
# Reads an issue draft file and files it via gh issue create.
#
# Usage:
#   claude-GitHub-file-issue <draft-file> [--repo OWNER/REPO]
#
# The draft file format is:
#   Line 1: issue title
#   Line 2: blank
#   Line 3+: issue body (markdown)
#
# If --repo is provided, the issue is filed against that repository.
# Otherwise gh infers the repo from the current git remote.
#
# Outputs the created issue URL on success.
# Exits non-zero and prints the gh error on failure.

set -euo pipefail

GH="@gh@"

if [ $# -lt 1 ]; then
  echo "Usage: claude-GitHub-file-issue <draft-file> [--repo OWNER/REPO]" >&2
  exit 1
fi

DRAFT_FILE="$1"
shift

if [ ! -f "$DRAFT_FILE" ]; then
  echo "Error: draft file not found: $DRAFT_FILE" >&2
  exit 1
fi

TITLE=$(head -1 "$DRAFT_FILE")
BODY=$(tail -n +3 "$DRAFT_FILE")

if [ -z "$TITLE" ]; then
  echo "Error: draft file has an empty title (line 1)" >&2
  exit 1
fi

# Remaining args are passed through to gh (e.g. --repo OWNER/REPO)
"$GH" issue create --title "$TITLE" --body "$BODY" "$@"
