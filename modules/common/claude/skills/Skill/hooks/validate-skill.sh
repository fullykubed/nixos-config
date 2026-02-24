#!/usr/bin/env bash
# Validates SKILL.md files after editing:
# - name field is required
# - description field is required and must contain "USE WHEN"
# - model field must be an alias (opus, sonnet, haiku) if set

set -euo pipefail

YQ="@yq@"
JQ="@jq@"

# Read JSON input from stdin
INPUT=$(cat)

# Extract file path from tool_input
FILE_PATH=$($JQ -r '.tool_input.file_path // empty' <<< "$INPUT")

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Only validate SKILL.md files
if [[ ! "$FILE_PATH" =~ SKILL\.md$ ]]; then
    exit 0
fi

if [[ ! -f "$FILE_PATH" ]]; then
    echo "File not found: $FILE_PATH" >&2
    exit 0
fi

echo "Validating: $FILE_PATH" >&2

ERRORS=()

# ---------------------------------------------------------------------------
# Validate name field (required)
# ---------------------------------------------------------------------------
NAME=$($YQ --front-matter=extract '.name // ""' "$FILE_PATH" 2>/dev/null || echo "")

if [[ -z "$NAME" || "$NAME" == "null" ]]; then
    ERRORS+=("Name field is missing or empty. It is required.")
fi

# ---------------------------------------------------------------------------
# Validate model field (optional, but must be an alias if set)
# ---------------------------------------------------------------------------
MODEL=$($YQ --front-matter=extract '.model // ""' "$FILE_PATH" 2>/dev/null || echo "")

if [[ -n "$MODEL" && "$MODEL" != "null" ]]; then
    ALLOWED_ALIASES=("opus" "sonnet" "haiku")
    VALID=false
    for alias in "${ALLOWED_ALIASES[@]}"; do
        if [[ "$MODEL" == "$alias" ]]; then
            VALID=true
            break
        fi
    done

    if [[ "$VALID" == "false" ]]; then
        ALIAS_LIST=$(printf ", %s" "${ALLOWED_ALIASES[@]}")
        ERRORS+=("Invalid model '$MODEL'. Only model aliases are allowed: ${ALIAS_LIST:2}. Full model IDs (e.g. claude-opus-4-6) are not permitted — use the alias instead so skills always resolve to the latest version.")
    fi
fi

# ---------------------------------------------------------------------------
# Validate description contains "USE WHEN"
# ---------------------------------------------------------------------------
DESCRIPTION=$($YQ --front-matter=extract '.description // ""' "$FILE_PATH" 2>/dev/null || echo "")

if [[ -n "$DESCRIPTION" && "$DESCRIPTION" != "null" ]]; then
    if [[ "$DESCRIPTION" != *"USE WHEN"* ]]; then
        ERRORS+=("Description must contain 'USE WHEN' to define trigger conditions (e.g. 'Manage X and Y. USE WHEN the user wants to...').")
    fi
else
    ERRORS+=("Description field is missing or empty. It must be set and contain 'USE WHEN'.")
fi

# ---------------------------------------------------------------------------
# Report results
# ---------------------------------------------------------------------------
if [[ ${#ERRORS[@]} -gt 0 ]]; then
    REASON=$(printf "%s " "${ERRORS[@]}")
    # shellcheck disable=SC2016 # $reason is a jq variable
    $JQ -n \
        --arg reason "Validation failed for $FILE_PATH: $REASON" \
        '{
            "decision": "block",
            "reason": $reason
        }'
    exit 0
fi

echo "OK" >&2
exit 0
