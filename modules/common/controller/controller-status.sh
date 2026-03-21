#!/usr/bin/env bash
# modules/common/controller/controller-status.sh
# Collects controller VM existence/status via hcloud and probes services when
# the VM is running.  Writes JSON to /run/controller-status/status.json.

set -euo pipefail

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

OUTPUT_DIR="/run/controller-status"
OUTPUT_FILE="${OUTPUT_DIR}/status.json"
OUTPUT_TMP="${OUTPUT_DIR}/status.json.tmp"

HOST_PUBKEY_FILE="/etc/ssh/cache-host-key.pub"
SSH_BASE_OPTS=(-i /root/.ssh/cache-key -o IdentitiesOnly=yes -p 3099)

# ------------------------------------------------------------------------------
# Logging helpers (all output goes to stderr)
# ------------------------------------------------------------------------------

info()  { echo ":: $*" >&2; }
warn()  { echo ":: Warning: $*" >&2; }

# ------------------------------------------------------------------------------
# Setup
# ------------------------------------------------------------------------------

mkdir -p "$OUTPUT_DIR"

# ------------------------------------------------------------------------------
# Query hcloud for controller VM
# ------------------------------------------------------------------------------

vm_exists=false
vm_name=""
vm_status=""
vm_ip=""
vm_server_type=""
vm_location=""

info "Querying hcloud for controller VM"

if vm_json=$(hcloud server list -l controller=true -o json 2>/dev/null); then
  vm_count=$(echo "$vm_json" | jaq -r 'length')

  if [[ "$vm_count" -gt 0 ]]; then
    vm_exists=true
    vm_name=$(echo "$vm_json" | jaq -r '.[0].name')
    vm_status=$(echo "$vm_json" | jaq -r '.[0].status')
    vm_ip=$(echo "$vm_json" | jaq -r '.[0].public_net.ipv4.ip // ""')
    vm_server_type=$(echo "$vm_json" | jaq -r '.[0].server_type.name // ""')
    vm_location=$(echo "$vm_json" | jaq -r '.[0].datacenter.location.name // ""')
    info "Found VM '${vm_name}' — status: ${vm_status}"
  else
    info "No controller VM found"
  fi
else
  warn "hcloud query failed; VM data will be unavailable"
fi

# ------------------------------------------------------------------------------
# Build VM JSON sub-object
# ------------------------------------------------------------------------------

if $vm_exists; then
  # shellcheck disable=SC2016
  vm_json_obj=$(jaq -cn \
    --argjson exists true \
    --arg name "$vm_name" \
    --arg status "$vm_status" \
    --arg ip "$vm_ip" \
    --arg serverType "$vm_server_type" \
    --arg location "$vm_location" \
    '{exists: $exists, name: $name, status: $status, ip: $ip, server_type: $serverType, location: $location}')
else
  # shellcheck disable=SC2016
  vm_json_obj=$(jaq -cn \
    --argjson exists false \
    '{exists: $exists, name: "", status: "", ip: "", server_type: "", location: ""}')
fi

# ------------------------------------------------------------------------------
# Probe services (only when VM is running)
# ------------------------------------------------------------------------------

services_json="null"

if $vm_exists && [[ "$vm_status" == "running" ]]; then
  info "VM is running — probing services"

  headscale_ok=false
  niks3_ok=false
  croc_ok=false
  ssh_ok=false

  # Headscale via public DNS endpoint (tests caddy + headscale + DNS)
  if curl -sf --max-time 5 -o /dev/null "https://headscale.panfactumcf.com/health" 2>/dev/null; then
    headscale_ok=true
  fi

  # niks3 via Tailscale (tests niks3 + postgresql + tailscale connectivity)
  if curl -sf --max-time 5 -o /dev/null "http://nix-controller:5751/health" 2>/dev/null; then
    niks3_ok=true
  fi

  # croc relay via VM public IP (TCP connect to relay port)
  if [[ -n "$vm_ip" ]]; then
    if timeout 5 "$BASH" -c "echo >/dev/tcp/${vm_ip}/19009" 2>/dev/null; then
      croc_ok=true
    fi
  else
    if timeout 5 "$BASH" -c 'echo >/dev/tcp/headscale.panfactumcf.com/19009' 2>/dev/null; then
      croc_ok=true
    fi
  fi

  # SSH auth check (mirrors controller-cli pattern: explicit opts + temp known_hosts)
  known_hosts_tmp=$(mktemp)
  echo "[${vm_ip}]:3099 $(cat "$HOST_PUBKEY_FILE")" > "$known_hosts_tmp"
  if ssh -T -o ConnectTimeout=5 -o BatchMode=yes \
    "${SSH_BASE_OPTS[@]}" -o StrictHostKeyChecking=yes \
    -o "UserKnownHostsFile=$known_hosts_tmp" \
    "root@${vm_ip}" true 2>/dev/null; then
    ssh_ok=true
  fi
  rm -f "$known_hosts_tmp"

  # shellcheck disable=SC2016
  services_json=$(jaq -cn \
    --argjson headscale "$headscale_ok" \
    --argjson niks3 "$niks3_ok" \
    --argjson croc "$croc_ok" \
    --argjson ssh "$ssh_ok" \
    '{headscale: $headscale, niks3: $niks3, croc: $croc, ssh: $ssh}')
else
  if $vm_exists; then
    info "VM status is '${vm_status}' — skipping service probes"
  fi
fi

# ------------------------------------------------------------------------------
# Write output JSON atomically
# ------------------------------------------------------------------------------

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

info "Writing status to ${OUTPUT_FILE}"

# shellcheck disable=SC2016
jaq -cn \
  --argjson vm "$vm_json_obj" \
  --argjson services "$services_json" \
  --arg timestamp "$timestamp" \
  '{vm: $vm, services: $services, timestamp: $timestamp}' > "$OUTPUT_TMP"

chmod 0644 "$OUTPUT_TMP"
mv "$OUTPUT_TMP" "$OUTPUT_FILE"

info "controller-status: done"
