#!/usr/bin/env bash
# Validates the structure of research.yaml files across all PRDs

set -euo pipefail

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
    research_file="${prd_dir}research.yaml"

    if [[ ! -f "$research_file" ]]; then
        continue
    fi

    echo "=== Validating $prd_name ===" >&2

    if ! $CHECK_JSONSCHEMA --schemafile "$SCHEMA_PATH" "$research_file" >&2 2>&1; then
        echo "  Schema validation failed: $research_file" >&2
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    else
        echo "  OK" >&2
    fi

    VALIDATED=$((VALIDATED + 1))
done

echo "" >&2
if [[ $VALIDATED -eq 0 ]]; then
    echo "No research.yaml files found." >&2
elif [[ $TOTAL_ERRORS -gt 0 ]]; then
    echo "Validation failed with $TOTAL_ERRORS error(s) across $VALIDATED PRD(s)." >&2
    exit 2
else
    echo "Validated $VALIDATED PRD(s) successfully." >&2
fi
