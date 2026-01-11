#!/usr/bin/env bash
# Lists all leaf tasks (tasks without subtasks) that are in draft status for a PRD

set -euo pipefail

YQ="@yq@"
JQ="@jq@"

if [[ $# -lt 1 ]]; then
    echo "Usage: claude-list-draft-tasks <prd-name>" >&2
    exit 1
fi

prd_name="$1"
prd_dir=".claude/prds/$prd_name"
tasks_file="${prd_dir}/tasks.yaml"

if [[ ! -d "$prd_dir" ]]; then
    echo "Error: PRD '$prd_name' not found at $prd_dir" >&2
    exit 1
fi

if [[ ! -f "$tasks_file" ]]; then
    echo "[]"
    exit 0
fi

# Extract all leaf tasks with draft status
# Leaf tasks are either top-level tasks with a status field, or subtasks
$YQ -o=json '
    [
        # Top-level leaf tasks (have status, no subtasks)
        (.[] | select(.status == "draft") | {
            "name": .name,
            "description": .description,
            "spec": .spec,
            "parent": null
        }),
        # Subtasks with draft status
        (.[] | select(.subtasks) | .name as $parent | .subtasks[] | select(.status == "draft") | {
            "name": .name,
            "description": .description,
            "spec": .spec,
            "parent": $parent
        })
    ]
' "$tasks_file" 2>/dev/null || echo '[]'
