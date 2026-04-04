#!/usr/bin/env bash
# Returns JSON describing task status counts for a given PRD

set -euo pipefail

JAQ="@jaq@"

usage() {
    echo "Usage: task-status <prd-name>"
    echo ""
    echo "Returns JSON with task counts by status and total."
    echo ""
    echo "Arguments:"
    echo "  prd-name    Name of the PRD (directory name under .claude/prds/)"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

PRD_NAME="$1"
TASKS_FILE=".claude/prds/${PRD_NAME}/tasks.yaml"

if [[ ! -f "$TASKS_FILE" ]]; then
    echo "Error: Tasks file not found: $TASKS_FILE" >&2
    exit 1
fi

# Count statuses from both top-level leaf tasks and subtasks
# Leaf tasks have a 'status' field directly
# Parent tasks have 'subtasks' array where each subtask has a 'status'
$JAQ --from yaml '
{
  "draft": [(.[] | select(.status == "draft")), (.[] | select(.subtasks) | .subtasks[] | select(.status == "draft"))] | length,
  "defined": [(.[] | select(.status == "defined")), (.[] | select(.subtasks) | .subtasks[] | select(.status == "defined"))] | length,
  "completed": [(.[] | select(.status == "completed")), (.[] | select(.subtasks) | .subtasks[] | select(.status == "completed"))] | length,
  "total": [(.[] | select(.status)), (.[] | select(.subtasks) | .subtasks[] | select(.status))] | length
}
' "$TASKS_FILE"
