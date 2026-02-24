#!/usr/bin/env bash
# Lists all leaf tasks (tasks without subtasks) that are in defined status for a PRD
# These are tasks ready for implementation

set -euo pipefail

YQ="@yq@"

if [[ $# -lt 1 ]]; then
    echo "Usage: claude-PRD-list-defined-tasks <prd-name>" >&2
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

# Extract all leaf tasks with defined status
# Leaf tasks are either top-level tasks with a status field, or subtasks
# shellcheck disable=SC2016 # $parent is a yq variable, not shell
$YQ -o=json '
    [
        # Top-level leaf tasks (have status, no subtasks)
        (.[] | select(.status == "defined") | {
            "name": .name,
            "description": .description,
            "spec": .spec,
            "parent": null
        }),
        # Subtasks with defined status
        (.[] | select(.subtasks) | .name as $parent | .subtasks[] | select(.status == "defined") | {
            "name": .name,
            "description": .description,
            "spec": .spec,
            "parent": $parent
        })
    ]
' "$tasks_file" 2>/dev/null || echo '[]'
