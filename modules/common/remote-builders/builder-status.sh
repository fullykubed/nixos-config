#!/usr/bin/env bash
# modules/common/remote-builders/builder-status.sh
# Polls Hetzner Cloud for the builder server list, fans out parallel SSH calls
# to each running builder to collect runtime metrics, merges the stats into the
# hcloud JSON, and writes the result atomically to /run/builder-status/status.json
# for waybar-builders.sh to read.
#
# The remote_stats placeholder below is replaced at build time (via
# builtins.replaceStrings in default.nix) with the contents of remote-stats.sh,
# so both this script and builders-cli.sh share the same metrics-collection
# snippet without runtime path dependencies.

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

OUTPUT_DIR="/run/builder-status"
OUTPUT_FILE="${OUTPUT_DIR}/status.json"
OUTPUT_TMP="${OUTPUT_DIR}/status.json.tmp"
HOST_PUBKEY_FILE="/etc/ssh/builder-host-key.pub"
SSH_KEY_FILE="/root/.ssh/builder-key"

# ------------------------------------------------------------------------------
# Logging helpers (all output to stderr — journalctl -u builder-status)
# ------------------------------------------------------------------------------

info()  { echo ":: $*" >&2; }
warn()  { echo ":: Warning: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

# ------------------------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------------------------

tmpdir=$(mktemp -d)
known_hosts_tmp=$(mktemp)
cleanup() { rm -rf "$tmpdir" "$known_hosts_tmp"; }
trap cleanup EXIT

# ------------------------------------------------------------------------------
# 1. Fetch hcloud builder list
# ------------------------------------------------------------------------------

HCLOUD_TOKEN=$(cat "${HCLOUD_TOKEN_FILE}")
export HCLOUD_TOKEN

hcloud_json=$(hcloud server list -o json -l builder=true)

# ------------------------------------------------------------------------------
# 2. Tailscale lookup: build name -> Tailscale IP map for running builders
# ------------------------------------------------------------------------------

ts_json=$(tailscale status --json 2>/dev/null || echo '{}')

declare -A name_ip
declare -a names

while IFS= read -r bname; do
  [[ -n "$bname" ]] || continue
  # $name below is a jaq variable, not a shell variable
  # shellcheck disable=SC2016
  ip=$(echo "$ts_json" | jaq -r --arg name "$bname" \
    '.Peer[] | select(.HostName == $name) | .TailscaleIPs[0]' 2>/dev/null || true)
  if [[ -n "$ip" && "$ip" != "null" ]]; then
    name_ip["$bname"]="$ip"
    names+=("$bname")
    echo "${ip} $(cat "$HOST_PUBKEY_FILE")" >> "$known_hosts_tmp"
  else
    warn "no Tailscale IP found for $bname — will mark unreachable"
  fi
done < <(echo "$hcloud_json" | jaq -r \
  '.[] | select(.name | test("^(big-)?builder-")) | select(.status == "running") | .name' \
  2>/dev/null)

# ------------------------------------------------------------------------------
# 3. REMOTE_STATS_CMD (substituted from remote-stats.sh at build time)
# ------------------------------------------------------------------------------

read -r -d '' REMOTE_STATS_CMD <<'STATSEOF' || true
@remote_stats@
STATSEOF

# ------------------------------------------------------------------------------
# 4. Parallel SSH fanout to each running builder
# ------------------------------------------------------------------------------

SSH_OPTS=(
  -F /dev/null
  -i "$SSH_KEY_FILE"
  -p 3098
  -o IdentitiesOnly=yes
  -o BatchMode=yes
  -o LogLevel=ERROR
  -o ConnectTimeout=3
  -o StrictHostKeyChecking=yes
  -o "UserKnownHostsFile=$known_hosts_tmp"
)

declare -a pids=()
for bname in "${names[@]}"; do
  (
    timeout 10 ssh "${SSH_OPTS[@]}" "remotebuild@${name_ip[$bname]}" \
      "$REMOTE_STATS_CMD" \
      > "$tmpdir/$bname" 2>/dev/null < /dev/null \
      || echo "ERROR" > "$tmpdir/$bname"
  ) &
  pids+=($!)
done
wait "${pids[@]}" 2>/dev/null || true

# ------------------------------------------------------------------------------
# 5. Parse per-builder output and build a stats JSON array
# ------------------------------------------------------------------------------

stats_json='[]'

# Add entries for non-running builders (present in hcloud but not started yet —
# e.g. status=starting, migrating). No SSH attempt is made for these.
while IFS= read -r bname; do
  [[ -n "$bname" ]] || continue
  # $name is a jaq variable
  # shellcheck disable=SC2016
  entry=$(jaq -n --arg name "$bname" '{name: $name, reachable: false}')
  # $arr/$e are jaq variables
  # shellcheck disable=SC2016
  stats_json=$(jaq -n \
    --argjson arr "$stats_json" \
    --argjson e   "$entry" \
    '$arr + [$e]')
done < <(echo "$hcloud_json" | jaq -r \
  '.[] | select(.name | test("^(big-)?builder-")) | select(.status != "running") | .name' \
  2>/dev/null)

# Parse SSH results for running builders.
for bname in "${names[@]}"; do
  data=$(grep -v '^[[:space:]]*$' "$tmpdir/$bname" 2>/dev/null | tail -1 || true)

  if [[ -z "$data" || "$data" == "ERROR" || "$data" != *"|"* ]]; then
    # $name is a jaq variable
    # shellcheck disable=SC2016
    entry=$(jaq -n --arg name "$bname" '{name: $name, reachable: false}')
  else
    # Field positions (1-indexed):
    #  1:builds  2:cpu  3:mu  4:mt  5:dr  6:dw  7:dst  8:dsu  9:dsp
    # 10:ssh_sessions  11:ts_status  12:q_pending  13:q_done  14:idle_count
    # 15:cc_hits  16:cc_misses  17:cc_size_kb  18:ccache_mount  19:ccache_sync
    IFS='|' read -r builds cpu mu mt _ _ _ _ _ _ ts_stat _ _ idle_count _ _ _ ccm ccs <<< "$data"
    builds=${builds:-0}
    cpu=${cpu:-0}
    mu=${mu:-0}
    mt=${mt:-0}
    idle_count=${idle_count:-0}
    ts_stat=${ts_stat:-unknown}
    ccm=${ccm:-1}
    ccs=${ccs:-1}

    mem_pct=0
    if [[ "${mt}" -gt 0 ]]; then
      mem_pct=$(( (mu * 100) / mt ))
      [[ $mem_pct -gt 100 ]] && mem_pct=100
      [[ $mem_pct -lt 0 ]] && mem_pct=0
    fi

    # ccm/ccs are 0 or 1 integers from remote-stats.sh; pass as JSON booleans.
    ccache_mount_bool="false"
    [[ "${ccm}" == "1" ]] && ccache_mount_bool="true"
    ccache_sync_bool="false"
    [[ "${ccs}" == "1" ]] && ccache_sync_bool="true"

    # $name/$ts/$ccm/$ccs are jaq variables
    # shellcheck disable=SC2016
    entry=$(jaq -n \
      --arg  name  "$bname" \
      --argjson builds "${builds}" \
      --argjson cpu    "${cpu}" \
      --argjson mem    "${mem_pct}" \
      --argjson idle   "${idle_count}" \
      --arg  ts    "${ts_stat}" \
      --argjson ccm    "${ccache_mount_bool}" \
      --argjson ccs    "${ccache_sync_bool}" \
      '{
        name:         $name,
        reachable:    true,
        builds:       $builds,
        cpu_pct:      $cpu,
        mem_pct:      $mem,
        idle_count:   $idle,
        ts_status:    $ts,
        ccache_mount: $ccm,
        ccache_sync:  $ccs
      }')
  fi

  # $arr/$e are jaq variables
  # shellcheck disable=SC2016
  stats_json=$(jaq -n \
    --argjson arr "$stats_json" \
    --argjson e   "$entry" \
    '$arr + [$e]')
done

# ------------------------------------------------------------------------------
# 6. Merge hcloud objects with per-builder stats by name
# ------------------------------------------------------------------------------

# For each hcloud entry, overlay the matching stats object (if any).
# Builders not matched in stats_json get reachable:false as a fallback.
# $h/$s/$b are jaq variables
# shellcheck disable=SC2016
merged=$(jaq -n \
  --argjson h "$hcloud_json" \
  --argjson s "$stats_json" \
  '$h | map(. as $b | $b + (($s[] | select(.name == $b.name)) // {reachable: false}))')

# ------------------------------------------------------------------------------
# 7. Atomic write
# ------------------------------------------------------------------------------

echo "$merged" > "$OUTPUT_TMP"
chmod 0644 "$OUTPUT_TMP"
mv -f "$OUTPUT_TMP" "$OUTPUT_FILE"

total=$(echo "$hcloud_json" | jaq 'length')
reachable=$(echo "$merged" | jaq '[.[] | select(.reachable)] | length')
info "wrote status.json (${reachable} reachable / ${total} total builders)"
