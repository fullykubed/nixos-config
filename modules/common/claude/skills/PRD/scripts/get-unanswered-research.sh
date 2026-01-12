#!/usr/bin/env bash
# Returns JSON array of unanswered research questions for a given PRD

set -euo pipefail

YQ="@yq@"

usage() {
    echo "Usage: claude-get-unanswered-research <prd-name>"
    echo ""
    echo "Returns JSON array of unanswered research questions."
    echo "Each question includes 'text' and 'mode' fields."
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

# Return unanswered questions (those without an answer)
$YQ -o=json '[.[] | select(.answer == null or .answer == "") | {text: .text, mode: .mode}]' "$RESEARCH_FILE"
