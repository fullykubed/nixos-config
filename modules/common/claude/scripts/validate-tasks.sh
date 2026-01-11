#!/usr/bin/env bash
# Validates the structure of tasks.yaml files across all PRDs

set -euo pipefail

YQ="@yq@"
CHECK_JSONSCHEMA="@check-jsonschema@"
SCHEMA_PATH="@schema-path@"

PRDS_DIR=".claude/prds"

if [[ ! -d "$PRDS_DIR" ]]; then
    echo "No PRDs directory found at $PRDS_DIR" >&2
    exit 0
fi

TOTAL_ERRORS=0
VALIDATED=0

for prd_dir in "$PRDS_DIR"/*/; do
    [[ -d "$prd_dir" ]] || continue

    prd_name=$(basename "$prd_dir")
    tasks_file="${prd_dir}tasks.yaml"

    if [[ ! -f "$tasks_file" ]]; then
        continue
    fi

    echo "=== Validating $prd_name ===" >&2
    ERRORS=0

    # Step 1: Validate against JSON schema
    if ! $CHECK_JSONSCHEMA --schemafile "$SCHEMA_PATH" "$tasks_file" >&2 2>&1; then
        echo "  Schema validation failed: $tasks_file" >&2
        ERRORS=$((ERRORS + 1))
    fi

    # Step 2: Check that tasks with status 'defined' have existing spec files
    SPEC_PATHS=$($YQ '
        [.[] | select(.status == "defined") | {name: .name, spec: .spec},
         .[] | .subtasks[]? | select(.status == "defined") | {name: .name, spec: .spec}]
        | .[] | .name + "|" + .spec
    ' "$tasks_file" 2>/dev/null || echo "")

    if [[ -n "$SPEC_PATHS" ]]; then
        while IFS='|' read -r task_name spec_path; do
            [[ -z "$task_name" ]] && continue

            full_spec_path="${prd_dir}${spec_path}"

            if [[ ! -f "$full_spec_path" ]]; then
                echo "  Error: Task '$task_name' has status 'defined' but spec file not found: $full_spec_path" >&2
                ERRORS=$((ERRORS + 1))
            fi
        done <<< "$SPEC_PATHS"
    fi

    if [[ $ERRORS -eq 0 ]]; then
        echo "  OK" >&2
    fi

    TOTAL_ERRORS=$((TOTAL_ERRORS + ERRORS))
    VALIDATED=$((VALIDATED + 1))
done

echo "" >&2
if [[ $VALIDATED -eq 0 ]]; then
    echo "No tasks.yaml files found." >&2
elif [[ $TOTAL_ERRORS -gt 0 ]]; then
    echo "Validation failed with $TOTAL_ERRORS error(s) across $VALIDATED PRD(s)." >&2
    exit 2
else
    echo "Validated $VALIDATED PRD(s) successfully." >&2
fi
