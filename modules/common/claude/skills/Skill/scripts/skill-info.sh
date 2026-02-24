#!/usr/bin/env bash
# shellcheck disable=SC2016 # jq expressions use $var syntax, not shell expansion
set -euo pipefail

# Get detailed info about a specific Claude skill
# Usage: claude-Skill-skill-info <skill-name>

if [[ $# -lt 1 ]]; then
  echo "Usage: claude-Skill-skill-info <skill-name>" >&2
  exit 1
fi

skill_name="$1"
skills_dir=".claude/skills"
skill_dir="$skills_dir/$skill_name"

if [[ ! -d "$skill_dir" ]]; then
  # shellcheck disable=SC2016 # $name is a jq variable, not shell
  @jq@ -n --arg name "$skill_name" '{error: "Skill \"\($name)\" not found", found: false}'
  exit 0
fi

skill_md="$skill_dir/SKILL.md"
if [[ ! -f "$skill_md" ]]; then
  # shellcheck disable=SC2016 # $dir is a jq variable, not shell
  @jq@ -n --arg dir "$skill_dir" '{error: "No SKILL.md found in \($dir)", found: false}'
  exit 0
fi

name=$(@yq@ --front-matter=extract '.name' "$skill_md")
description=$(@yq@ --front-matter=extract '.description' "$skill_md")
model=$(@yq@ --front-matter=extract '.model // "default"' "$skill_md")

# List workflows
workflows="[]"
if [[ -d "$skill_dir/workflows" ]]; then
  workflows=$(find "$skill_dir/workflows" -maxdepth 1 -name "*.md" -exec basename {} .md \; | sort | @jq@ -R . | @jq@ -s .)
fi

# List reference files
references="[]"
if [[ -d "$skill_dir/reference" ]]; then
  references=$(find "$skill_dir/reference" -maxdepth 1 -name "*.md" -exec basename {} .md \; | sort | @jq@ -R . | @jq@ -s .)
fi

# List scripts
scripts="[]"
if [[ -d "$skill_dir/scripts" ]]; then
  scripts=$(find "$skill_dir/scripts" -maxdepth 1 -name "*.sh" -exec basename {} .sh \; | sort | @jq@ -R . | @jq@ -s .)
fi

# List schemas
schemas="[]"
if [[ -d "$skill_dir/schemas" ]]; then
  schemas=$(find "$skill_dir/schemas" -maxdepth 1 -name "*.json" -exec basename {} \; | sort | @jq@ -R . | @jq@ -s .)
fi

# shellcheck disable=SC2016 # $name/$description etc. are jq variables, not shell
@jq@ -n \
  --arg name "$name" \
  --arg description "$description" \
  --arg model "$model" \
  --arg path "$skill_dir" \
  --argjson workflows "$workflows" \
  --argjson references "$references" \
  --argjson scripts "$scripts" \
  --argjson schemas "$schemas" \
  '{
    found: true,
    name: $name,
    description: $description,
    model: $model,
    path: $path,
    workflows: $workflows,
    references: $references,
    scripts: $scripts,
    schemas: $schemas
  }'
