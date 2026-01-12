#!/usr/bin/env bash
# Returns full task details for a specific task in a PRD
# This utility eliminates the need for work-prd-task to read tasks.yaml directly

set -euo pipefail

YQ="@yq@"
JQ="@jq@"

usage() {
    echo "Usage: claude-get-task <prd-name> <task-name>"
    echo ""
    echo "Returns JSON with full task details including status, spec path, and dependencies."
    echo ""
    echo "Arguments:"
    echo "  prd-name    Name of the PRD (directory name under .claude/prds/)"
    echo "  task-name   Name of the task to retrieve"
    echo ""
    echo "Output JSON structure:"
    echo "  {"
    echo "    \"name\": \"Task name\","
    echo "    \"description\": \"Task description\","
    echo "    \"status\": \"draft|defined|completed\","
    echo "    \"spec\": \"path/to/spec.md\","
    echo "    \"spec_path\": \".claude/prds/<prd>/path/to/spec.md\","
    echo "    \"parent\": \"Parent task name or null\","
    echo "    \"prd_name\": \"PRD name\","
    echo "    \"prd_path\": \".claude/prds/<prd>/PRD.md\","
    echo "    \"log_path\": \".claude/prds/<prd>/log.md\","
    echo "    \"log_exists\": true|false,"
    echo "    \"found\": true|false,"
    echo "    \"error\": \"Error message if not found\""
    echo "  }"
    exit 1
}

if [[ $# -lt 2 ]]; then
    usage
fi

PRD_NAME="$1"
TASK_NAME="$2"

PRD_DIR=".claude/prds/${PRD_NAME}"
TASKS_FILE="${PRD_DIR}/tasks.yaml"
PRD_FILE="${PRD_DIR}/PRD.md"
LOG_FILE="${PRD_DIR}/log.md"

# Check if PRD directory exists
if [[ ! -d "$PRD_DIR" ]]; then
    $JQ -n --arg name "$TASK_NAME" --arg prd "$PRD_NAME" \
        '{found: false, name: $name, prd_name: $prd, error: "PRD directory not found"}'
    exit 0
fi

# Check if tasks file exists
if [[ ! -f "$TASKS_FILE" ]]; then
    $JQ -n --arg name "$TASK_NAME" --arg prd "$PRD_NAME" \
        '{found: false, name: $name, prd_name: $prd, error: "tasks.yaml not found"}'
    exit 0
fi

# Check if log file exists
LOG_EXISTS="false"
if [[ -f "$LOG_FILE" ]]; then
    LOG_EXISTS="true"
fi

# Try to find the task (either as top-level leaf task or subtask)
TASK_JSON=$($YQ -o=json "
    # First try top-level leaf tasks (have status field directly)
    (.[] | select(.name == \"$TASK_NAME\" and .status) | {
        \"name\": .name,
        \"description\": .description,
        \"status\": .status,
        \"spec\": .spec,
        \"parent\": null
    }) //
    # Then try subtasks
    (.[] | select(.subtasks) | .name as \$parent | .subtasks[] | select(.name == \"$TASK_NAME\") | {
        \"name\": .name,
        \"description\": .description,
        \"status\": .status,
        \"spec\": .spec,
        \"parent\": \$parent
    }) //
    null
" "$TASKS_FILE" 2>/dev/null)

# Check if task was found
if [[ "$TASK_JSON" == "null" || -z "$TASK_JSON" ]]; then
    $JQ -n --arg name "$TASK_NAME" --arg prd "$PRD_NAME" \
        '{found: false, name: $name, prd_name: $prd, error: "Task not found in tasks.yaml"}'
    exit 0
fi

# Get the spec path from the task
SPEC_REL=$(echo "$TASK_JSON" | $JQ -r '.spec // ""')

# Build full spec path
if [[ -n "$SPEC_REL" ]]; then
    SPEC_PATH="${PRD_DIR}/${SPEC_REL}"
else
    SPEC_PATH=""
fi

# Check if spec file exists
SPEC_EXISTS="false"
if [[ -n "$SPEC_PATH" && -f "$SPEC_PATH" ]]; then
    SPEC_EXISTS="true"
fi

# Add additional context to the task JSON
echo "$TASK_JSON" | $JQ \
    --arg prd_name "$PRD_NAME" \
    --arg prd_path "$PRD_FILE" \
    --arg log_path "$LOG_FILE" \
    --argjson log_exists "$LOG_EXISTS" \
    --arg spec_path "$SPEC_PATH" \
    --argjson spec_exists "$SPEC_EXISTS" \
    '. + {
        found: true,
        prd_name: $prd_name,
        prd_path: $prd_path,
        log_path: $log_path,
        log_exists: $log_exists,
        spec_path: $spec_path,
        spec_exists: $spec_exists
    }'
