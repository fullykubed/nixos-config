#!/usr/bin/env bash
# Lists all PRDs with their status based on task completion

set -euo pipefail

JAQ="@jaq@"

PRDS_DIR=".claude/prds"

if [[ ! -d "$PRDS_DIR" ]]; then
    echo "[]"
    exit 0
fi

# Build JSON array of PRD statuses
results="[]"

for prd_dir in "$PRDS_DIR"/*/; do
    [[ -d "$prd_dir" ]] || continue

    prd_name=$(basename "$prd_dir")
    tasks_file="${prd_dir}tasks.yaml"

    if [[ ! -f "$tasks_file" ]]; then
        # shellcheck disable=SC2016 # $name is a jaq variable, not a shell variable
        results=$($JAQ --arg name "$prd_name" \
            '. += [{"name": $name, "status": "no-tasks", "completed": 0, "total": 0}]' <<< "$results")
        continue
    fi

    # Count completed and total tasks (both top-level leaf tasks and subtasks)
    counts=$($JAQ --from yaml '
        {
            "completed": [.[] | select(.status == "completed"), .[] | select(.subtasks) | .subtasks[] | select(.status == "completed")] | length,
            "total": [.[] | select(.status), .[] | select(.subtasks) | .subtasks[] | select(.status)] | length
        }
    ' "$tasks_file" 2>/dev/null || echo '{"completed":0,"total":0}')

    completed=$($JAQ -r '.completed' <<< "$counts")
    total=$($JAQ -r '.total' <<< "$counts")

    if [[ "$total" -eq 0 ]]; then
        status="no-tasks"
    elif [[ "$completed" -eq 0 ]]; then
        status="draft"
    elif [[ "$completed" -eq "$total" ]]; then
        status="complete"
    else
        status="in-progress"
    fi

    # shellcheck disable=SC2016 # $name/$status/$completed/$total are jaq variables, not shell variables
    results=$($JAQ --arg name "$prd_name" --arg status "$status" \
        --argjson completed "$completed" --argjson total "$total" \
        '. += [{"name": $name, "status": $status, "completed": $completed, "total": $total}]' <<< "$results")
done

echo "$results" | $JAQ '.'
