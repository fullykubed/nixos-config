#!/usr/bin/env bash
# Lists all open surprise files as a JSON array
# Output format: [{"slug": "...", "category": "...", "title": "...", "date": "..."}]

set -euo pipefail

JQ="@jq@"

MAIN_WORKTREE=$(git-default-worktree-path)

SURPRISES_DIR="${MAIN_WORKTREE}/.claude/surprises"

# Return empty array if surprises directory does not exist
if [[ ! -d "$SURPRISES_DIR" ]]; then
    echo "[]"
    exit 0
fi

results="[]"

for file in "$SURPRISES_DIR"/*.md; do
    # Skip glob if no files match
    [[ -f "$file" ]] || continue

    slug=$(basename "$file" .md)

    # Extract category from frontmatter (line starting with "category: ")
    category=$(awk '/^---/{if(++fence==2) exit} fence==1 && /^category:/{sub(/^category:[[:space:]]*/, ""); print; exit}' "$file")

    # Extract date from frontmatter (line starting with "date: ")
    date=$(awk '/^---/{if(++fence==2) exit} fence==1 && /^date:/{sub(/^date:[[:space:]]*/, ""); print; exit}' "$file")

    # Extract title from first H1 heading (line starting with "# ")
    title=$(awk '/^# /{sub(/^# /, ""); print; exit}' "$file")

    # shellcheck disable=SC2016  # jq uses $var syntax, not shell expansion
    results=$("$JQ" \
        --arg slug "$slug" \
        --arg category "$category" \
        --arg title "$title" \
        --arg date "$date" \
        '. += [{"slug": $slug, "category": $category, "title": $title, "date": $date}]' \
        <<< "$results")
done

echo "$results" | "$JQ" '.'
