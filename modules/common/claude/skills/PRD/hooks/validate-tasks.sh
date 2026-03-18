#!/usr/bin/env bash
# Validates the structure of a tasks.yaml file after editing

set -euo pipefail

JAQ="@jaq@"
CHECK_JSONSCHEMA="@check-jsonschema@"
SCHEMA_PATH="@schema-path@"

# Read JSON input from stdin
INPUT=$(cat)

# Extract file path from tool_input
FILE_PATH=$($JAQ -r '.tool_input.file_path // empty' <<< "$INPUT")

if [[ -z "$FILE_PATH" ]]; then
    # Not a file operation, skip
    exit 0
fi

# Only validate tasks.yaml files in .claude directory
if [[ ! "$FILE_PATH" =~ \.claude/.*tasks\.yaml$ ]]; then
    exit 0
fi

if [[ ! -f "$FILE_PATH" ]]; then
    echo "File not found: $FILE_PATH" >&2
    exit 0
fi

echo "Validating: $FILE_PATH" >&2

ERRORS=0
ERROR_MESSAGES=""

# Step 1: Validate against JSON schema
if ! SCHEMA_OUTPUT=$($CHECK_JSONSCHEMA --schemafile "$SCHEMA_PATH" "$FILE_PATH" 2>&1); then
    ERROR_MESSAGES="Schema validation failed: $SCHEMA_OUTPUT"
    ERRORS=$((ERRORS + 1))
fi

# Step 2: Check that tasks with status 'defined' have existing spec files
PRD_DIR=$(dirname "$FILE_PATH")
SPEC_PATHS=$($JAQ --from yaml '
    [.[] | select(.status == "defined") | {"name": .name, "spec": .spec},
     .[] | .subtasks[]? | select(.status == "defined") | {"name": .name, "spec": .spec}]
    | .[] | .name + "|" + .spec
' "$FILE_PATH" 2>/dev/null || echo "")

if [[ -n "$SPEC_PATHS" ]]; then
    while IFS='|' read -r task_name spec_path; do
        [[ -z "$task_name" ]] && continue

        full_spec_path="${PRD_DIR}/${spec_path}"

        if [[ ! -f "$full_spec_path" ]]; then
            if [[ -n "$ERROR_MESSAGES" ]]; then
                ERROR_MESSAGES="$ERROR_MESSAGES; "
            fi
            ERROR_MESSAGES="${ERROR_MESSAGES}Task '$task_name' has status 'defined' but spec file not found: $full_spec_path"
            ERRORS=$((ERRORS + 1))
        fi
    done <<< "$SPEC_PATHS"
fi

if [[ $ERRORS -gt 0 ]]; then
    # Output structured response for Claude
    # shellcheck disable=SC2016 # $reason is a jaq variable, not shell
    $JAQ -n \
        --arg reason "Validation failed for $FILE_PATH: $ERROR_MESSAGES" \
        '{
            "decision": "block",
            "reason": $reason
        }'
    exit 0
fi

echo "OK" >&2
exit 0
