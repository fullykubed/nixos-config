#!/usr/bin/env bash
# Validates the structure of a research.yaml file after editing

set -euo pipefail

CHECK_JSONSCHEMA="@check-jsonschema@"
SCHEMA_PATH="@schema-path@"
JQ="@jq@"

# Read JSON input from stdin
INPUT=$(cat)

# Extract file path from tool_input
FILE_PATH=$($JQ -r '.tool_input.file_path // empty' <<< "$INPUT")

if [[ -z "$FILE_PATH" ]]; then
    # Not a file operation, skip
    exit 0
fi

# Only validate research.yaml files
if [[ ! "$FILE_PATH" =~ research\.yaml$ ]]; then
    exit 0
fi

if [[ ! -f "$FILE_PATH" ]]; then
    echo "File not found: $FILE_PATH" >&2
    exit 0
fi

echo "Validating: $FILE_PATH" >&2

if ! $CHECK_JSONSCHEMA --schemafile "$SCHEMA_PATH" "$FILE_PATH" 2>&1; then
    # Output structured response for Claude
    $JQ -n \
        --arg reason "Schema validation failed for $FILE_PATH. Please fix the YAML structure." \
        '{
            "decision": "block",
            "reason": $reason
        }'
    exit 0
fi

echo "OK" >&2
exit 0
