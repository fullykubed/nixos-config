#!/usr/bin/env bash
set -euo pipefail

# List all Claude skills from both repository-level and system-level locations
# Outputs JSON array with skill details including tier

results="[]"

scan_dir() {
  local skills_dir="$1"
  local tier="$2"

  if [[ ! -d "$skills_dir" ]]; then
    return
  fi

  for skill_dir in "$skills_dir"/*/; do
    # Skip if glob didn't match
    [[ -d "$skill_dir" ]] || continue

    skill_md="${skill_dir}SKILL.md"
    if [[ ! -f "$skill_md" ]]; then
      continue
    fi

    name=$(@extract-frontmatter@ "$skill_md" | @jaq@ --from yaml -r '.name')
    description=$(@extract-frontmatter@ "$skill_md" | @jaq@ --from yaml -r '.description')

    # Count and list workflows
    workflows="[]"
    workflow_count=0
    if [[ -d "${skill_dir}workflows" ]]; then
      workflows=$(find "${skill_dir}workflows" -maxdepth 1 -name "*.md" -exec basename {} .md \; | sort | @jaq@ -R . | @jaq@ -s .)
      workflow_count=$(echo "$workflows" | @jaq@ 'length')
    fi

    # shellcheck disable=SC2016 # $name/$dir/$desc/$tier etc. are jq variables, not shell
    results=$(echo "$results" | @jaq@ \
      --arg name "$name" \
      --arg desc "$description" \
      --arg dir "$(basename "$skill_dir")" \
      --arg tier "$tier" \
      --arg path "$skills_dir" \
      --argjson wf_count "$workflow_count" \
      --argjson workflows "$workflows" \
      '. + [{name: $name, directory: $dir, tier: $tier, path: ($path + "/" + $dir), description: $desc, workflow_count: $wf_count, workflows: $workflows}]')
  done
}

# Scan repository-level skills
scan_dir ".claude/skills" "repo"

# Scan system-level skills (deployed to ~/.claude/skills/ at runtime,
# but in the NixOS config repo they live under modules/common/claude/skills/)
SYSTEM_SKILLS_DIR="modules/common/claude/skills"
if [[ -d "$SYSTEM_SKILLS_DIR" ]]; then
  scan_dir "$SYSTEM_SKILLS_DIR" "system"
fi

echo "$results" | @jaq@ .
