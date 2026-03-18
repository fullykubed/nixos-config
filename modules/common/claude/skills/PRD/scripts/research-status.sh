#!/usr/bin/env bash
# Returns JSON describing research question status for a given PRD

set -euo pipefail

JAQ="@jaq@"

usage() {
    echo "Usage: claude-PRD-research-status <prd-name>"
    echo ""
    echo "Returns JSON with research question counts by status and total."
    echo "A question is 'complete' if it has an answer, 'draft' otherwise."
    echo ""
    echo "Arguments:"
    echo "  prd-name    Name of the PRD (directory name under .claude/prds/)"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

PRD_NAME="$1"
RESEARCH_FILE=".claude/prds/${PRD_NAME}/research.yaml"

if [[ ! -f "$RESEARCH_FILE" ]]; then
    echo "Error: Research file not found: $RESEARCH_FILE" >&2
    exit 1
fi

# Count questions by status
# A question is 'complete' if it has an answer, 'draft' otherwise
$JAQ --from yaml '
{
  "draft": [.[] | select(.answer == null or .answer == "")] | length,
  "complete": [.[] | select((.answer == null or .answer == "") | not)] | length,
  "total": length
}
' "$RESEARCH_FILE"
