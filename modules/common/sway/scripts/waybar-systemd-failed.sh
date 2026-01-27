#!/usr/bin/env bash
#
# Waybar systemd failed services monitor
# Checks for failed systemd services and units with bad-setting load status
# (both system and user) and outputs JSON formatted for Waybar's custom module protocol.
#
# Output: JSON with text, alt, tooltip, and class fields
# - When healthy: empty text (module hidden)
# - When issues: warning icon with count, tooltip lists affected units
#

set -o pipefail

# Configuration
readonly ICON=$'\uf071'  # Nerd Font warning icon (U+F071)

# Extract unit name from systemctl output
# Handles the ● prefix that systemctl adds for problem units
extract_unit_name() {
  awk '{if ($1 ~ /^[^a-zA-Z]/) print $2; else print $1}'
}

# Get list of problem units
get_failed_units() {
  local scope="$1"  # "" for system, "--user" for user
  systemctl $scope --failed --no-legend 2>/dev/null | extract_unit_name
}

get_bad_setting_units() {
  local scope="$1"  # "" for system, "--user" for user
  systemctl $scope list-units --all --no-legend 2>/dev/null | awk '/bad-setting/' | extract_unit_name
}

# Count non-empty lines
count_units() {
  local input="$1"
  if [[ -z "$input" ]]; then
    echo 0
  else
    echo "$input" | grep -c .
  fi
}

# Append units to tooltip
append_to_tooltip() {
  local units="$1"
  local label="$2"
  local tooltip="$3"

  while IFS= read -r unit; do
    [[ -n "$unit" ]] && tooltip="${tooltip}\n• ${label}: ${unit}"
  done <<< "$units"

  echo "$tooltip"
}

# Collect problem units
system_failed=$(get_failed_units "")
user_failed=$(get_failed_units "--user")
system_bad=$(get_bad_setting_units "")
user_bad=$(get_bad_setting_units "--user")

# Count totals
system_failed_count=$(count_units "$system_failed")
user_failed_count=$(count_units "$user_failed")
system_bad_count=$(count_units "$system_bad")
user_bad_count=$(count_units "$user_bad")
total_count=$((system_failed_count + user_failed_count + system_bad_count + user_bad_count))

# Output empty JSON if no issues (hides the module)
if [[ "$total_count" -eq 0 ]]; then
  echo '{"text": "", "alt": "ok", "tooltip": "", "class": "ok"}'
  exit 0
fi

# Build tooltip with problem units
tooltip="Problem units:"
[[ "$system_failed_count" -gt 0 ]] && tooltip=$(append_to_tooltip "$system_failed" "system (failed)" "$tooltip")
[[ "$user_failed_count" -gt 0 ]] && tooltip=$(append_to_tooltip "$user_failed" "user (failed)" "$tooltip")
[[ "$system_bad_count" -gt 0 ]] && tooltip=$(append_to_tooltip "$system_bad" "system (bad-setting)" "$tooltip")
[[ "$user_bad_count" -gt 0 ]] && tooltip=$(append_to_tooltip "$user_bad" "user (bad-setting)" "$tooltip")

# Output JSON for Waybar (use %s to keep \n as literal characters)
printf '{"text": "%s %d", "alt": "failed", "tooltip": "%s", "class": "failed"}\n' "$ICON" "$total_count" "$tooltip"
