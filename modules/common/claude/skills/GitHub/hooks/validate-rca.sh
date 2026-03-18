#!/usr/bin/env bash
# Validates the RCA output file written by the github-rca agent
# against the JSON schema using check-jsonschema.

set -euo pipefail

CHECK_JSONSCHEMA="@check-jsonschema@"
SCHEMA_PATH="@schema-path@"
JAQ="@jaq@"

# Read JSON input from stdin
INPUT=$(cat)

# Extract file path from tool_input
FILE_PATH=$($JAQ -r '.tool_input.file_path // empty' <<< "$INPUT")

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Only validate RCA output files
if [[ ! "$FILE_PATH" =~ gh-rca-.*\.json$ ]]; then
    exit 0
fi

if [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi

echo "Validating RCA output: $FILE_PATH" >&2

if ! $CHECK_JSONSCHEMA --schemafile "$SCHEMA_PATH" "$FILE_PATH" 2>&1 >&2; then
    exit 2
fi

# ---------------------------------------------------------------------------
# Validate that all source file references are GitHub permalinks.
# A bare path like "src/auth.ts:42" must be a permalink instead.
# ---------------------------------------------------------------------------
PERMALINK_RE='^https://github\.com/.+/blob/[0-9a-f]+/.+#L[0-9]+'
BARE_PATH_RE='^[a-zA-Z0-9_./-]+\.[a-zA-Z]+:[0-9]+'

BAD_REFS=()

# Check evidence entries
while IFS= read -r entry; do
    # Extract the reference portion before any " — " description
    ref="${entry%% — *}"

    # Skip entries that are not file references (e.g. commit SHAs, prose)
    if [[ ! "$ref" =~ $BARE_PATH_RE ]] && [[ ! "$ref" =~ $PERMALINK_RE ]]; then
        continue
    fi

    if [[ ! "$ref" =~ $PERMALINK_RE ]]; then
        BAD_REFS+=("evidence: $ref")
    fi
done < <($JAQ -r '.evidence[]' "$FILE_PATH")

# Check suggested_fixes change locations
while IFS= read -r location; do
    if [[ ! "$location" =~ $PERMALINK_RE ]]; then
        BAD_REFS+=("suggested_fixes.changes.location: $location")
    fi
done < <($JAQ -r '.suggested_fixes[].changes[].location' "$FILE_PATH")

if [[ ${#BAD_REFS[@]} -gt 0 ]]; then
    echo "Source file references must be GitHub permalinks:" >&2
    printf "  %s\n" "${BAD_REFS[@]}" >&2
    echo "Required format: https://github.com/OWNER/REPO/blob/SHA/path#Lline" >&2
    exit 2
fi

exit 0
