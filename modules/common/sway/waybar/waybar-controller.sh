#!/usr/bin/env bash
# modules/common/sway/waybar/waybar-controller.sh
# Waybar custom module for controller VM health.
# Reads status from /run/controller-status/status.json (written by systemd).

ICON=$'\uf0c2' # nf-fa-cloud
STATUS_FILE="/run/controller-status/status.json"
STALE_SECONDS=300 # 5 minutes

# ------------------------------------------------------------------------------
# Status file missing — service hasn't run yet
# ------------------------------------------------------------------------------

if [[ ! -f "$STATUS_FILE" ]]; then
  tooltip="Controller: status unknown
  Waiting for controller-status service..."
  # shellcheck disable=SC2016
  jaq -cn \
    --arg text "$ICON ?" \
    --arg tooltip "$tooltip" \
    --arg class "offline" \
    '{text: $text, tooltip: $tooltip, class: $class}'
  exit 0
fi

status=$(cat "$STATUS_FILE")

# ------------------------------------------------------------------------------
# Parse VM info
# ------------------------------------------------------------------------------

vm_exists=$(echo "$status" | jaq -r '.vm.exists')
vm_status=$(echo "$status" | jaq -r '.vm.status')
vm_name=$(echo "$status" | jaq -r '.vm.name')
vm_ip=$(echo "$status" | jaq -r '.vm.ip')
vm_server_type=$(echo "$status" | jaq -r '.vm.server_type')
vm_location=$(echo "$status" | jaq -r '.vm.location')
timestamp=$(echo "$status" | jaq -r '.timestamp')

# ------------------------------------------------------------------------------
# Check staleness
# ------------------------------------------------------------------------------

stale_warning=""
if [[ -n "$timestamp" ]]; then
  file_epoch=$(date -d "$timestamp" +%s 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  age=$(( now_epoch - file_epoch ))
  if (( age > STALE_SECONDS )); then
    stale_warning="
  ⚠ Status is $(( age / 60 ))m old"
  fi
fi

# ------------------------------------------------------------------------------
# VM not provisioned
# ------------------------------------------------------------------------------

if [[ "$vm_exists" != "true" ]]; then
  tooltip="Controller: not provisioned${stale_warning}"
  # shellcheck disable=SC2016
  jaq -cn \
    --arg text "$ICON" \
    --arg tooltip "$tooltip" \
    --arg class "offline" \
    '{text: $text, tooltip: $tooltip, class: $class}'
  exit 0
fi

# ------------------------------------------------------------------------------
# VM exists but not running
# ------------------------------------------------------------------------------

if [[ "$vm_status" != "running" ]]; then
  tooltip="Controller: ${vm_status}
  VM: ${vm_name} (${vm_server_type}, ${vm_location})${stale_warning}"
  # shellcheck disable=SC2016
  jaq -cn \
    --arg text "$ICON !" \
    --arg tooltip "$tooltip" \
    --arg class "offline" \
    '{text: $text, tooltip: $tooltip, class: $class}'
  exit 0
fi

# ------------------------------------------------------------------------------
# VM running — check service health
# ------------------------------------------------------------------------------

has_services=$(echo "$status" | jaq -r '.services != null')

if [[ "$has_services" != "true" ]]; then
  tooltip="Controller: running (no service data)
  VM: ${vm_name} (${vm_server_type}, ${vm_location})${stale_warning}"
  # shellcheck disable=SC2016
  jaq -cn \
    --arg text "$ICON ?" \
    --arg tooltip "$tooltip" \
    --arg class "degraded" \
    '{text: $text, tooltip: $tooltip, class: $class}'
  exit 0
fi

headscale_ok=$(echo "$status" | jaq -r '.services.headscale')
niks3_ok=$(echo "$status" | jaq -r '.services.niks3')
croc_ok=$(echo "$status" | jaq -r '.services.croc')
ssh_ok=$(echo "$status" | jaq -r '.services.ssh')

# Count healthy services
healthy=0
if [[ "$headscale_ok" == "true" ]]; then healthy=$((healthy + 1)); fi
if [[ "$niks3_ok" == "true" ]]; then healthy=$((healthy + 1)); fi
if [[ "$croc_ok" == "true" ]]; then healthy=$((healthy + 1)); fi
if [[ "$ssh_ok" == "true" ]]; then healthy=$((healthy + 1)); fi

if (( healthy == 4 )); then
  class="healthy"
  text="$ICON"
  header="Controller: healthy"
elif (( healthy > 0 )); then
  class="degraded"
  text="$ICON !"
  header="Controller: degraded"
else
  class="offline"
  text="$ICON !"
  header="Controller: services unreachable"
fi

# Build per-service status lines
if [[ "$headscale_ok" == "true" ]]; then
  hs_line="  ● headscale: healthy"
else
  hs_line="  ○ headscale: unreachable"
fi

if [[ "$niks3_ok" == "true" ]]; then
  n3_line="  ● niks3: healthy"
else
  n3_line="  ○ niks3: unreachable"
fi

if [[ "$croc_ok" == "true" ]]; then
  croc_line="  ● croc relay: healthy"
else
  croc_line="  ○ croc relay: unreachable"
fi

if [[ "$ssh_ok" == "true" ]]; then
  ssh_line="  ● ssh: healthy"
else
  ssh_line="  ○ ssh: unreachable"
fi

# VM metadata line
vm_line="  VM: ${vm_name} (${vm_server_type}, ${vm_location})"
if [[ -n "$vm_ip" ]]; then
  vm_line="${vm_line}
  IP: ${vm_ip}"
fi

tooltip="${header}
${hs_line}
${n3_line}
${croc_line}
${ssh_line}
${vm_line}${stale_warning}"

# shellcheck disable=SC2016
jaq -cn \
  --arg text "$text" \
  --arg tooltip "$tooltip" \
  --arg class "$class" \
  '{text: $text, tooltip: $tooltip, class: $class}'
