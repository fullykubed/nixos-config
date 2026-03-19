#!/usr/bin/env bash
# modules/common/sway/waybar/waybar-secureboot-status.sh
# Waybar custom module for Secure Boot status via sbctl

set -euo pipefail

status_json=$(sbctl status --json)

secure_boot=$(echo "$status_json" | jaq -r '.secure_boot')
setup_mode=$(echo "$status_json" | jaq -r '.setup_mode')
installed=$(echo "$status_json" | jaq -r '.installed')

if [[ "$secure_boot" == "true" ]]; then
  text="󰒃"
  tooltip="Secure Boot: active"
  class="ok"
elif [[ "$setup_mode" == "true" ]]; then
  text="󱛊 Setup"
  tooltip="Secure Boot disabled — Setup Mode active (keys not enrolled)"
  class="setup"
elif [[ "$installed" != "true" ]]; then
  text="󰕦 Not Installed"
  tooltip="Secure Boot disabled — keys not installed"
  class="error"
else
  text="󱈸 Disabled"
  tooltip="Secure Boot: disabled"
  class="warning"
fi

# shellcheck disable=SC2016
jaq -cn \
  --arg text "$text" \
  --arg tooltip "$tooltip" \
  --arg class "$class" \
  '{text: $text, tooltip: $tooltip, class: $class}'
