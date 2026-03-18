#!/usr/bin/env bash
# modules/common/remote-builders/builders-cli.sh
# CLI tool for managing Hetzner Cloud remote builders (two-tier: regular + big-parallel)

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
TOKEN_FILE="/run/agenix/hetzner-api-token"
PUBKEY_FILE="/etc/ssh/builder-key.pub"
HOST_KEY_FILE="/run/agenix/builder-host-key"
HOST_PUBKEY_FILE="/etc/ssh/builder-host-key.pub"
CACHE_SSH_KEY_FILE="/root/.ssh/cache-key"
CACHE_HOST_PUBKEY_FILE="/etc/ssh/cache-host-key.pub"
NIKS3_TOKEN_FILE="/run/agenix/niks3-api-token"
CCACHE_R2_ACCESS_KEY_FILE="/run/agenix/ccache-r2-access-key"
CCACHE_R2_SECRET_KEY_FILE="/run/agenix/ccache-r2-secret-key"
# Resolve the latest builder snapshot by label (or use explicit override)
resolve_snapshot_id() {
  if [[ -n "${HETZNER_BUILDER_SNAPSHOT:-}" ]]; then
    echo "$HETZNER_BUILDER_SNAPSHOT"
    return
  fi
  local id
  id=$(hcloud image list -t snapshot -l type=builder -o json 2>/dev/null \
    | jaq -r 'sort_by(.created) | last | .id // empty')
  if [[ -z "$id" ]]; then
    echo -e "${RED}Error: No snapshot found with label type=builder${NC}" >&2
    echo "Upload a builder image first, or set HETZNER_BUILDER_SNAPSHOT." >&2
    exit 1
  fi
  echo "$id"
}
LOCATION="hel1"

# Server types per tier
REGULAR_SERVER_TYPE="cpx42"
BIG_SERVER_TYPE="ccx33"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Hourly costs in EUR
REGULAR_HOURLY_COST="0.0268"
BIG_HOURLY_COST="0.0950"

# Base SSH options (host key verification added dynamically per IP)
# -F /dev/null: skip user/system SSH config to avoid failures when HOME points
# to a home-manager-managed ~/.ssh/config owned by nobody (Nix store).
SSH_BASE_OPTS=(-F /dev/null -i /root/.ssh/builder-key -p 3098)
SSH_OPTS=() # populated by setup_host_verification

# Temporary known hosts file for host key verification
_KNOWN_HOSTS_TMP=""
_cleanup_known_hosts() {
  [[ -n "$_KNOWN_HOSTS_TMP" ]] && rm -f "$_KNOWN_HOSTS_TMP"
}
trap '_cleanup_known_hosts' EXIT

# Set up host key verification for one or more builder IPs.
# Generates a temporary known_hosts with [ip]:3098 entries mapped to our known host public key.
# Usage: setup_host_verification IP [IP2 IP3 ...]
setup_host_verification() {
  if [[ ! -f "$HOST_PUBKEY_FILE" ]]; then
    echo -e "${RED}Error: Host public key not found at $HOST_PUBKEY_FILE${NC}" >&2
    echo "Cannot verify builder identity without the host public key." >&2
    exit 1
  fi
  local pubkey
  pubkey=$(cat "$HOST_PUBKEY_FILE")
  _KNOWN_HOSTS_TMP=$(mktemp)
  for ip in "$@"; do
    echo "[${ip}]:3098 ${pubkey}" >> "$_KNOWN_HOSTS_TMP"
  done
  SSH_OPTS=("${SSH_BASE_OPTS[@]}" -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$_KNOWN_HOSTS_TMP")
}

# Track SSH tunnel control sockets for cleanup on exit
_TUNNEL_CTLS=()
_cleanup_tunnels() {
  for ctl in "${_TUNNEL_CTLS[@]}"; do
    ssh -o "ControlPath=$ctl" -O exit dummy 2>/dev/null || true
    rm -f "$ctl"
  done
  _TUNNEL_CTLS=()
}
trap '_cleanup_tunnels' EXIT

# Find a free local TCP port
find_free_port() {
  python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'
}

# Spinner for long-running tests. Usage:
#   start_spinner "running test"
#   ... long command ...
#   stop_spinner
SPINNER_PID=""
start_spinner() {
  local msg="${1:-}"
  (
    chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    i=0
    while true; do
      printf '\r%s %b%s%b ' "$msg" "$YELLOW" "${chars:i%${#chars}:1}" "$NC" >&2
      i=$((i + 1))
      sleep 0.1
    done
  ) &
  SPINNER_PID=$!
}
stop_spinner() {
  if [[ -n "$SPINNER_PID" ]]; then
    kill "$SPINNER_PID" 2>/dev/null || true
    wait "$SPINNER_PID" 2>/dev/null || true
    SPINNER_PID=""
    printf '\r' >&2
  fi
}

# Remote script that collects all builder metrics in a single SSH call.
# Outputs pipe-delimited: builds|cpu%|mem_used_kb|mem_total_kb|disk_read_sectors|disk_write_sectors|disk_total_kb|disk_used_kb|disk_pct|ssh_sessions|tunnel_status|queue_pending|queue_done|idle_count
# Disk sectors are cumulative counters; the dashboard computes rates from deltas between refreshes.
read -r -d '' REMOTE_STATS_CMD << 'STATSEOF' || true
b=$(ps -eo user= 2>/dev/null | sort -u | grep -c '^nixbld' || true); b=${b:-0}
sc=$(command ss -Htn state established '( sport = :3098 )' 2>/dev/null | wc -l)
ss=$((sc > 1 ? sc - 1 : 0))
read _ u1 n1 s1 i1 w1 _ < /proc/stat
sleep 1
read _ u2 n2 s2 i2 w2 _ < /proc/stat
t1=$((u1+n1+s1+i1+w1)); t2=$((u2+n2+s2+i2+w2))
dt=$((t2-t1)); di=$((i2-i1))
if [ $dt -gt 0 ]; then cpu=$(((dt-di)*100/dt)); else cpu=0; fi
dr=0; dw=0
while read _ _ dn _ _ sr _ _ _ sw _; do
  case $dn in sda|vda|nvme0n1|xvda) dr=$sr; dw=$sw; break;; esac
done < /proc/diskstats
mt=0; ma=0
while read k v _; do
  case $k in MemTotal:) mt=$v;; MemAvailable:) ma=$v;; esac
done < /proc/meminfo
mu=$((mt-ma))
dline=$(df -k /nix/store | tail -1)
dst=$(echo "$dline" | tr -s ' ' | cut -d' ' -f2)
dsu=$(echo "$dline" | tr -s ' ' | cut -d' ' -f3)
dsp=$(echo "$dline" | tr -s ' ' | cut -d' ' -f5 | tr -d '%')
tun=$(systemctl is-active cache-tunnel.service 2>/dev/null || echo "dead")
pq=$(find /var/lib/cache-upload-queue/pending -maxdepth 1 -type f 2>/dev/null | wc -l)
dq=$(find /var/lib/cache-upload-queue/done -maxdepth 1 -type f 2>/dev/null | wc -l)
ic=$(cat /var/lib/inactivity-monitor/idle-count 2>/dev/null || echo 0)
printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' "$b" "$cpu" "$mu" "$mt" "$dr" "$dw" "$dst" "$dsu" "$dsp" "$ss" "$tun" "$pq" "$dq" "$ic"
STATSEOF

# --- Type helpers ---

# Determine builder type from name: "big" or "regular"
builder_type() {
  local name="$1"
  if [[ "$name" == big-builder-* ]]; then
    echo "big"
  else
    echo "regular"
  fi
}

# Get server type for a builder name
server_type_for() {
  if [[ "$(builder_type "$1")" == "big" ]]; then
    echo "$BIG_SERVER_TYPE"
  else
    echo "$REGULAR_SERVER_TYPE"
  fi
}

# Get hourly cost for a builder name
hourly_cost_for() {
  if [[ "$(builder_type "$1")" == "big" ]]; then
    echo "$BIG_HOURLY_COST"
  else
    echo "$REGULAR_HOURLY_COST"
  fi
}

# Check if a name is a valid builder name
is_builder_name() {
  local name="$1"
  [[ "$name" =~ ^(big-)?builder-[0-9]+$ ]]
}

# Normalize input: bare numbers become "builder-N", full names pass through
normalize_name() {
  local arg="$1"
  if [[ "$arg" =~ ^[0-9]+$ ]]; then
    echo "builder-$arg"
  else
    echo "$arg"
  fi
}

show_help() {
  cat <<EOF
Usage: $SCRIPT_NAME <command> [options]

Builder types:
  builder-N       Regular builder (${REGULAR_SERVER_TYPE}, 8 shared vCPU, 16 GB RAM)
                  For many parallel small builds
  big-builder-N   Big-parallel builder (${BIG_SERVER_TYPE}, 8 dedicated vCPU, 32 GB RAM)
                  For heavy builds (Chromium, LLVM, Rust)

Commands:
  list              List all active builders with details
  status            Show summary of builders and estimated costs
  dashboard         Live-updating resource dashboard for all builders
  check <name>      Check SSH connectivity and Nix on a builder
  create <name>     Create a builder manually
  destroy <name>    Destroy a builder
  destroy -a        Destroy all builders (requires confirmation)
  destroy-all       Destroy all builders (requires confirmation)
  debug-stats <name> Show raw SSH stats output (for debugging dashboard)
  help              Show this help message

Examples:
  $SCRIPT_NAME list
  $SCRIPT_NAME create builder-1
  $SCRIPT_NAME create big-builder-1
  $SCRIPT_NAME check builder-1
  $SCRIPT_NAME destroy big-builder-1
EOF
}

check_token() {
  if [[ ! -f "$TOKEN_FILE" ]]; then
    echo -e "${RED}Error: Hetzner API token not found at $TOKEN_FILE${NC}" >&2
    exit 1
  fi
  export HCLOUD_TOKEN
  HCLOUD_TOKEN=$(cat "$TOKEN_FILE")
}

cmd_list() {
  check_token
  echo -e "${GREEN}Active Builders:${NC}"
  echo ""

  local servers_json
  servers_json=$(hcloud server list -o json 2>/dev/null || echo '[]')

  local builders
  builders=$(echo "$servers_json" | jaq -r '.[] | select(.name | test("^(big-)?builder-")) | "\(.name)\t\(.status)\t\(.public_net.ipv4.ip)\t\(.created)"' | sort)

  if [[ -z "$builders" ]]; then
    echo "No builders found."
  else
    printf "%-18s %-10s %-16s %s\n" "NAME" "STATUS" "IPV4" "CREATED"
    echo "$builders" | column -t -s $'\t'
  fi
}

cmd_status() {
  check_token

  local servers_json
  servers_json=$(hcloud server list -o json 2>/dev/null || echo '[]')

  local regular_count big_count
  regular_count=$(echo "$servers_json" | jaq '[.[] | select(.name | test("^builder-"))] | length')
  big_count=$(echo "$servers_json" | jaq '[.[] | select(.name | test("^big-builder-"))] | length')

  local regular_cost big_cost total_cost
  regular_cost=$(echo "$regular_count * $REGULAR_HOURLY_COST" | bc)
  big_cost=$(echo "$big_count * $BIG_HOURLY_COST" | bc)
  total_cost=$(echo "$regular_cost + $big_cost" | bc)

  local total_count=$((regular_count + big_count))

  echo -e "${GREEN}Builder Status Summary${NC}"
  echo "========================"
  echo "Regular builders:     $regular_count  (${REGULAR_SERVER_TYPE} @ ~${REGULAR_HOURLY_COST}/hr)"
  echo "Big-parallel builders: $big_count  (${BIG_SERVER_TYPE} @ ~${BIG_HOURLY_COST}/hr)"
  echo "Total hourly cost: ${total_cost}"
  echo ""

  if [[ $total_count -gt 0 ]]; then
    echo "Builders:"
    echo "$servers_json" | jaq -r '.[] | select(.name | test("^(big-)?builder-")) | "  \(.name)\t\(.status)\t\(.public_net.ipv4.ip)"' | sort | column -t -s $'\t'
  fi
}

cmd_check() {
  local name="$1"

  check_token

  echo -e "${YELLOW}Checking $name...${NC}"

  # Check if server exists
  if ! hcloud server describe "$name" &>/dev/null; then
    echo -e "${RED}Builder $name does not exist${NC}"
    return 1
  fi

  local ip
  ip=$(hcloud server describe "$name" -o json | jaq -r '.public_net.ipv4.ip')
  echo -e "IP: ${GREEN}${ip}${NC}"

  # Set up host key verification for this builder
  setup_host_verification "$ip"

  # Check SSH connectivity with verbose debug on failure
  echo -n "SSH connectivity: "
  local ssh_err ssh_exit
  ssh_err=$(mktemp)
  ssh -o ConnectTimeout=10 -o BatchMode=yes "${SSH_OPTS[@]}" "remotebuild@$ip" "true" 2>"$ssh_err" && ssh_exit=0 || ssh_exit=$?
  if [[ "$ssh_exit" -eq 0 ]]; then
    echo -e "${GREEN}OK${NC}"
    rm -f "$ssh_err"
  else
    echo -e "${RED}FAILED${NC}"
    echo ""
    echo -e "  ${RED}--- SSH debug ---${NC}"
    echo -e "  Exit code: $ssh_exit"
    echo -e "  Target:    remotebuild@${ip}:3098"
    echo -e "  Key:       /root/.ssh/builder-key"

    # Key file check
    if [[ -f /root/.ssh/builder-key ]]; then
      echo -e "  Key file:  ${GREEN}exists${NC} ($(stat -c '%A' /root/.ssh/builder-key))"
    else
      echo -e "  Key file:  ${RED}MISSING${NC}"
    fi

    # SSH stderr
    if [[ -s "$ssh_err" ]]; then
      echo ""
      echo -e "  ${RED}--- SSH stderr ---${NC}"
      sed 's/^/  /' "$ssh_err"
    fi

    echo ""

    # Port reachability
    echo -n "  Port 3098: "
    if timeout 3 bash -c "echo >/dev/tcp/$ip/3098" 2>/dev/null; then
      echo -e "${GREEN}reachable${NC} (SSH handshake or auth failed)"
    else
      echo -e "${RED}NOT reachable${NC} (firewall, sshd not running, or cloud-init still in progress)"
    fi

    # Verbose SSH trace (filtered to useful lines)
    echo ""
    echo -e "  ${YELLOW}--- Verbose SSH trace ---${NC}"
    (ssh -vvv -o ConnectTimeout=10 -o BatchMode=yes "${SSH_OPTS[@]}" "remotebuild@$ip" "true" 2>&1 || true) \
      | grep -iE '(debug1:|error|denied|refused|timeout|closed|banner|identity|offering|authentic|host key)' \
      | head -30 \
      | sed 's/^/  /'

    rm -f "$ssh_err"
    return 1
  fi

  # Check Nix
  echo -n "Nix version: "
  local nix_ver
  if nix_ver=$(ssh -o ConnectTimeout=10 "${SSH_OPTS[@]}" "remotebuild@$ip" "nix --version" 2>/dev/null); then
    echo -e "${GREEN}${nix_ver}${NC}"
  else
    echo -e "${RED}FAILED${NC}"
    return 1
  fi

  # CPU and memory info (single SSH call)
  echo -n "CPU: "
  local hw_info
  if hw_info=$(ssh -o ConnectTimeout=10 "${SSH_OPTS[@]}" "remotebuild@$ip" '
    cores=$(nproc)
    model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
    kb=$(awk "/^MemTotal:/{print \$2}" /proc/meminfo)
    gb_w=$((kb / 1048576)); gb_f=$(( (kb % 1048576) * 10 / 1048576 ))
    printf "%s|%s|%s.%s" "$cores" "$model" "$gb_w" "$gb_f"
  ' 2>/dev/null); then
    local hw_cores hw_model hw_mem
    IFS='|' read -r hw_cores hw_model hw_mem <<< "$hw_info"
    echo -e "${GREEN}${hw_cores}x ${hw_model}${NC}"
    echo -e "Memory: ${GREEN}${hw_mem} GB${NC}"
  else
    echo -e "${YELLOW}SKIPPED${NC}"
  fi

  # CPU perf benchmark: SHA256 hash + xz compression
  # These are the two most CPU-bound operations during Nix builds:
  #   - SHA256: Nix hashes every store path and build output
  #   - xz: Nix compresses NAR archives for the binary cache
  start_spinner "CPU perf (30s):"
  local bench_output
  if bench_output=$(ssh -o ConnectTimeout=45 "${SSH_OPTS[@]}" "remotebuild@$ip" '
    cores=$(nproc)

    # Single-core SHA256 for ~15s (nix hashes every store path)
    s=$(date +%s%N)
    deadline=$(( $(date +%s) + 15 ))
    total=0
    while [ $(date +%s) -lt $deadline ]; do
      dd if=/dev/zero bs=1M count=256 2>/dev/null | sha256sum >/dev/null
      total=$((total + 256))
    done
    e=$(date +%s%N)
    elapsed_ms=$(( (e - s) / 1000000 ))
    if [ $elapsed_ms -gt 0 ]; then hash_mbs=$((total * 1000 / elapsed_ms)); else hash_mbs=0; fi

    # All-core xz for ~15s (nix compresses NAR archives)
    s=$(date +%s%N)
    deadline=$(( $(date +%s) + 15 ))
    total=0
    while [ $(date +%s) -lt $deadline ]; do
      dd if=/dev/zero bs=1M count=32 2>/dev/null | xz -T0 -6 >/dev/null
      total=$((total + 32))
    done
    e=$(date +%s%N)
    elapsed_ms=$(( (e - s) / 1000000 ))
    if [ $elapsed_ms -gt 0 ]; then xz_mbs=$((total * 1000 / elapsed_ms)); else xz_mbs=0; fi

    printf "%s|%s|%s" "$hash_mbs" "$xz_mbs" "$cores"
  ' 2>/dev/null); then
    stop_spinner
    local hash_mbs xz_mbs bench_cores
    IFS='|' read -r hash_mbs xz_mbs bench_cores <<< "$bench_output"
    echo -e "CPU perf: ${GREEN}SHA256: ${hash_mbs} MB/s (1 core) | xz -6: ${xz_mbs} MB/s (${bench_cores} cores)${NC}"
  else
    stop_spinner
    echo -e "CPU perf: ${YELLOW}SKIPPED${NC}"
  fi

  # iperf3 bandwidth test over SSH tunnel (30s)
  local iperf_port
  iperf_port=$(find_free_port)

  # Start iperf3 server on builder and wait for it to be listening
  local _iperf_ready=false
  if ssh -o ConnectTimeout=10 "${SSH_OPTS[@]}" "remotebuild@$ip" "
    pkill -x iperf3 2>/dev/null
    sleep 1
    iperf3 -s -D -p $iperf_port --bind 127.0.0.1
    for i in \$(seq 1 10); do
      ss -tln | grep -q ':$iperf_port ' && exit 0
      sleep 0.5
    done
    exit 1
  " 2>/dev/null; then
    _iperf_ready=true
  fi

  # Open SSH tunnel: forward local iperf_port to builder's localhost:iperf_port
  local ssh_ctl
  ssh_ctl=$(mktemp -u /tmp/ssh-tunnel-XXXXXX)
  if [[ "$_iperf_ready" == "true" ]]; then
    ssh -o ConnectTimeout=10 "${SSH_OPTS[@]}" -f -N \
        -o ControlMaster=yes -o "ControlPath=$ssh_ctl" \
        -L "$iperf_port:127.0.0.1:$iperf_port" "remotebuild@$ip" 2>/dev/null
    _TUNNEL_CTLS+=("$ssh_ctl")
    sleep 1
  fi

  if [[ "$_iperf_ready" == "true" ]]; then
    start_spinner "Network bandwidth (30s):"
    local iperf_output iperf_err
    iperf_err=$(mktemp)
    if iperf_output=$(iperf3 -c 127.0.0.1 -t 30 -p "$iperf_port" -J 2>"$iperf_err"); then
      stop_spinner
      local send_bps receive_bps
      send_bps=$(echo "$iperf_output" | jaq '.end.sum_sent.bits_per_second // 0')
      receive_bps=$(echo "$iperf_output" | jaq '.end.sum_received.bits_per_second // 0')
      local send_mbps receive_mbps
      send_mbps=$(echo "scale=1; $send_bps / 1000000" | bc)
      receive_mbps=$(echo "scale=1; $receive_bps / 1000000" | bc)
      echo -e "Network bandwidth: ${GREEN}${send_mbps} Mbit/s send, ${receive_mbps} Mbit/s receive${NC}"
    else
      stop_spinner
      local iperf_json_err
      iperf_json_err=$(echo "$iperf_output" | jaq -r '.error // empty' 2>/dev/null)
      echo -e "Network bandwidth: ${YELLOW}SKIPPED${NC}"
      [[ -n "$iperf_json_err" ]] && echo -e "  ${RED}iperf3: ${iperf_json_err}${NC}"
    fi
    rm -f "$iperf_err"
  else
    echo -e "Network bandwidth: ${YELLOW}SKIPPED (iperf3 server failed to start on builder)${NC}"
  fi

  # Clean up: stop remote iperf3 server and SSH tunnel
  ssh -o ConnectTimeout=5 "${SSH_OPTS[@]}" "remotebuild@$ip" \
      "pkill -x iperf3" 2>/dev/null || true
  ssh -o "ControlPath=$ssh_ctl" -O exit remotebuild@"$ip" 2>/dev/null || true
  rm -f "$ssh_ctl"
  _TUNNEL_CTLS=("${_TUNNEL_CTLS[@]/$ssh_ctl/}")

  # Disk space check
  echo -n "Disk space: "
  local disk_output
  if disk_output=$(ssh -o ConnectTimeout=10 "${SSH_OPTS[@]}" "remotebuild@$ip" \
      "df -h /nix/store --output=size,used,avail,pcent | tail -1" 2>/dev/null); then
    local size _used avail pct
    read -r size _used avail pct <<< "$disk_output"
    echo -e "${GREEN}${avail} available / ${size} total (${pct} used)${NC}"
  else
    echo -e "${YELLOW}SKIPPED${NC}"
  fi

  # Disk performance (fio)
  start_spinner "Disk performance (30s):"
  local fio_output
  if fio_output=$(ssh -o ConnectTimeout=10 "${SSH_OPTS[@]}" "remotebuild@$ip" \
      "fio --name=test --ioengine=libaio --direct=1 --bs=4k --size=256M \
       --rw=randrw --rwmixread=70 --iodepth=32 --runtime=30 --time_based \
       --filename=/tmp/fio-test --output-format=json --group_reporting 2>/dev/null && rm -f /tmp/fio-test" 2>/dev/null); then
    stop_spinner
    local read_iops read_bw_mb write_iops write_bw_mb
    read_iops=$(echo "$fio_output" | jaq '.jobs[0].read.iops // 0 | floor')
    read_bw_mb=$(echo "$fio_output" | jaq '.jobs[0].read.bw // 0' | xargs -I{} echo "scale=1; {} / 1024" | bc)
    write_iops=$(echo "$fio_output" | jaq '.jobs[0].write.iops // 0 | floor')
    write_bw_mb=$(echo "$fio_output" | jaq '.jobs[0].write.bw // 0' | xargs -I{} echo "scale=1; {} / 1024" | bc)
    echo -e "Disk performance: ${GREEN}read: ${read_iops} IOPS ${read_bw_mb} MB/s | write: ${write_iops} IOPS ${write_bw_mb} MB/s (4K randrw 70/30)${NC}"
  else
    stop_spinner
    echo -e "Disk performance: ${YELLOW}SKIPPED (fio failed)${NC}"
  fi

  # Check cache tunnel
  echo -n "Cache tunnel: "
  local tun_status
  if tun_status=$(ssh -o ConnectTimeout=10 "${SSH_OPTS[@]}" "remotebuild@$ip" \
      'systemctl is-active cache-tunnel.service 2>/dev/null || echo inactive' 2>/dev/null); then
    if [[ "$tun_status" == "active" ]]; then
      # Verify tunnel endpoint
      local tun_health
      tun_health=$(ssh -o ConnectTimeout=10 "${SSH_OPTS[@]}" "remotebuild@$ip" \
        'curl -s -o /dev/null -w "%{http_code}" --max-time 2 http://127.0.0.1:9751/health 2>/dev/null || echo 000' 2>/dev/null)
      if [[ "$tun_health" == "200" ]]; then
        echo -e "${GREEN}OK (tunnel active, niks3 reachable)${NC}"
      else
        echo -e "${YELLOW}DEGRADED (tunnel active, niks3 HTTP $tun_health)${NC}"
      fi
    else
      echo -e "${YELLOW}$tun_status${NC}"
    fi
  else
    echo -e "${YELLOW}SKIPPED (SSH error)${NC}"
  fi

  # Inactivity shutdown estimate
  echo -n "Auto-shutdown: "
  local shutdown_info
  if shutdown_info=$(ssh -o ConnectTimeout=10 "${SSH_OPTS[@]}" "remotebuild@$ip" '
    timer=$(systemctl is-active inactivity-monitor.timer 2>/dev/null || echo inactive)
    idle=$(cat /var/lib/inactivity-monitor/idle-count 2>/dev/null || echo 0)
    active=0
    ps -eo user= 2>/dev/null | sort -u | grep -q "^nixbld" && active=1
    printf "%s|%s|%s" "$timer" "$idle" "$active"
  ' 2>/dev/null); then
    local timer_state idle_count is_active
    IFS='|' read -r timer_state idle_count is_active <<< "$shutdown_info"
    idle_count=${idle_count:-0}
    if [[ "$timer_state" != "active" ]]; then
      echo -e "${YELLOW}timer not running${NC}"
    elif [[ "$is_active" == "1" ]]; then
      echo -e "${GREEN}idle counter reset (builder active)${NC}"
    else
      local remaining=$(( 15 - idle_count ))
      if [[ $remaining -le 2 ]]; then
        echo -e "${RED}~${remaining} min remaining (idle ${idle_count}/15 min)${NC}"
      elif [[ $remaining -le 5 ]]; then
        echo -e "${YELLOW}~${remaining} min remaining (idle ${idle_count}/15 min)${NC}"
      else
        echo -e "${GREEN}~${remaining} min remaining (idle ${idle_count}/15 min)${NC}"
      fi
    fi
  else
    echo -e "${YELLOW}SKIPPED (SSH error)${NC}"
  fi

  echo -e "${GREEN}Builder $name is healthy${NC}"
}

cmd_create() {
  local name="$1"

  check_token

  local snapshot_id
  snapshot_id=$(resolve_snapshot_id)

  if [[ ! -f "$PUBKEY_FILE" ]]; then
    echo -e "${RED}Error: SSH public key not found at $PUBKEY_FILE${NC}" >&2
    exit 1
  fi

  if [[ ! -f "$HOST_KEY_FILE" ]]; then
    echo -e "${RED}Error: Builder host key not found at $HOST_KEY_FILE${NC}" >&2
    exit 1
  fi

  if [[ ! -f "$CACHE_SSH_KEY_FILE" ]]; then
    echo -e "${RED}Error: Cache SSH key not found at $CACHE_SSH_KEY_FILE${NC}" >&2
    exit 1
  fi

  if [[ ! -f "$CACHE_HOST_PUBKEY_FILE" ]]; then
    echo -e "${RED}Error: Cache host public key not found at $CACHE_HOST_PUBKEY_FILE${NC}" >&2
    exit 1
  fi

  if [[ ! -f "$NIKS3_TOKEN_FILE" ]]; then
    echo -e "${RED}Error: niks3 API token not found at $NIKS3_TOKEN_FILE${NC}" >&2
    exit 1
  fi

  if [[ ! -f "$CCACHE_R2_ACCESS_KEY_FILE" ]]; then
    echo -e "${RED}Error: ccache R2 access key not found at $CCACHE_R2_ACCESS_KEY_FILE${NC}" >&2
    return 1
  fi

  if [[ ! -f "$CCACHE_R2_SECRET_KEY_FILE" ]]; then
    echo -e "${RED}Error: ccache R2 secret key not found at $CCACHE_R2_SECRET_KEY_FILE${NC}" >&2
    return 1
  fi

  local server_type
  server_type=$(server_type_for "$name")
  local btype
  btype=$(builder_type "$name")

  echo -e "${YELLOW}Creating $name (${btype}, ${server_type})...${NC}"

  # Read SSH public key for injection
  local ssh_pubkey
  ssh_pubkey=$(cat "$PUBKEY_FILE")

  # Read host key pair for injection (enables host key verification)
  local host_privkey host_pubkey
  host_privkey=$(cat "$HOST_KEY_FILE")
  host_pubkey=$(cat "$HOST_PUBKEY_FILE")

  # Read cache keys and niks3 token for injection
  local cache_ssh_key cache_host_pubkey niks3_token
  cache_ssh_key=$(cat "$CACHE_SSH_KEY_FILE")
  cache_host_pubkey=$(cat "$CACHE_HOST_PUBKEY_FILE")
  niks3_token=$(cat "$NIKS3_TOKEN_FILE")

  # Read ccache R2 credentials for injection
  local ccache_r2_access_key ccache_r2_secret_key
  ccache_r2_access_key=$(cat "$CCACHE_R2_ACCESS_KEY_FILE")
  ccache_r2_secret_key=$(cat "$CCACHE_R2_SECRET_KEY_FILE")

  # Build cloud-init user-data to inject SSH keys and host keys
  local user_data_file
  user_data_file=$(mktemp)
  trap 'rm -f "$user_data_file"' RETURN

  if [[ "$btype" == "big" ]]; then
    # Big-parallel builder: write nix override conf and restart nix-daemon
    cat > "$user_data_file" <<EOF
#cloud-config
ssh_pwauth: false
chpasswd:
  expire: false
write_files:
  - path: /run/hcloud-token
    permissions: '0400'
    content: |
      $(cat "$TOKEN_FILE")
  - path: /var/lib/remotebuild/.ssh/authorized_keys
    permissions: '0600'
    owner: remotebuild:remotebuild
    content: |
      $ssh_pubkey
  - path: /root/.ssh/authorized_keys
    permissions: '0600'
    content: |
      $ssh_pubkey
  - path: /etc/ssh/ssh_host_ed25519_key
    permissions: '0600'
    content: |
      ${host_privkey//$'\n'/$'\n'      }
  - path: /etc/ssh/ssh_host_ed25519_key.pub
    permissions: '0644'
    content: |
      $host_pubkey
  - path: /etc/nix/builder-override.conf
    permissions: '0644'
    content: |
      max-jobs = 1
      cores = 0
  - path: /root/.ssh/cache-key
    permissions: '0600'
    content: |
      ${cache_ssh_key//$'\n'/$'\n'      }
  - path: /etc/ssh/cache-host-key.pub
    permissions: '0644'
    content: |
      $cache_host_pubkey
  - path: /run/niks3-auth-token
    permissions: '0400'
    content: |
      $niks3_token
  - path: /run/sccache-r2-access-key
    permissions: '0400'
    content: |
      $ccache_r2_access_key
  - path: /run/sccache-r2-secret-key
    permissions: '0400'
    content: |
      $ccache_r2_secret_key
runcmd:
  - systemctl restart nix-daemon
  - systemctl start cache-tunnel.service
  - systemctl start inactivity-monitor.timer
  - systemctl start ccache-r2-mount.service
EOF
  else
    # Regular builder: no nix overrides needed
    cat > "$user_data_file" <<EOF
#cloud-config
ssh_pwauth: false
chpasswd:
  expire: false
write_files:
  - path: /run/hcloud-token
    permissions: '0400'
    content: |
      $(cat "$TOKEN_FILE")
  - path: /var/lib/remotebuild/.ssh/authorized_keys
    permissions: '0600'
    owner: remotebuild:remotebuild
    content: |
      $ssh_pubkey
  - path: /root/.ssh/authorized_keys
    permissions: '0600'
    content: |
      $ssh_pubkey
  - path: /etc/ssh/ssh_host_ed25519_key
    permissions: '0600'
    content: |
      ${host_privkey//$'\n'/$'\n'      }
  - path: /etc/ssh/ssh_host_ed25519_key.pub
    permissions: '0644'
    content: |
      $host_pubkey
  - path: /root/.ssh/cache-key
    permissions: '0600'
    content: |
      ${cache_ssh_key//$'\n'/$'\n'      }
  - path: /etc/ssh/cache-host-key.pub
    permissions: '0644'
    content: |
      $cache_host_pubkey
  - path: /run/niks3-auth-token
    permissions: '0400'
    content: |
      $niks3_token
  - path: /run/sccache-r2-access-key
    permissions: '0400'
    content: |
      $ccache_r2_access_key
  - path: /run/sccache-r2-secret-key
    permissions: '0400'
    content: |
      $ccache_r2_secret_key
runcmd:
  - systemctl start cache-tunnel.service
  - systemctl start inactivity-monitor.timer
  - systemctl start ccache-r2-mount.service
EOF
  fi

  hcloud server create \
    --name "$name" \
    --type "$server_type" \
    --image "$snapshot_id" \
    --location "$LOCATION" \
    --label "builder=true" \
    --label "type=builder" \
    --label "size=$btype" \
    --user-data-from-file "$user_data_file" \
    --poll-interval 2s

  echo -e "${GREEN}Created $name${NC}"
}

cmd_destroy() {
  local name="$1"

  check_token

  if ! hcloud server describe "$name" &>/dev/null; then
    echo -e "${YELLOW}Builder $name does not exist${NC}"
    return
  fi

  echo -e "${YELLOW}Destroying $name...${NC}"
  hcloud server delete "$name"
  echo -e "${GREEN}Destroyed $name${NC}"
}

cmd_destroy_all() {
  check_token

  local servers
  servers=$(hcloud server list -o json 2>/dev/null \
    | jaq -r '.[] | select(.name | test("^(big-)?builder-")) | .name' | sort)

  if [[ -z "$servers" ]]; then
    echo "No builders to destroy."
    return
  fi

  echo -e "${RED}WARNING: This will destroy the following builders:${NC}"
  echo "$servers"
  echo ""
  read -r -p "Type 'yes' to confirm: " confirm

  if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    return
  fi

  for server in $servers; do
    echo -e "${YELLOW}Destroying $server...${NC}"
    hcloud server delete "$server"
  done

  echo -e "${GREEN}All builders destroyed${NC}"
}

# --- Dashboard helpers ---

# Format KB value as GB with 1 decimal place
format_kb() {
  local kb=${1:-0}
  local whole=$((kb / 1048576))
  local frac=$(( (kb % 1048576) * 10 / 1048576 ))
  echo "${whole}.${frac}"
}

# Print a percentage with color based on thresholds
color_pct() {
  local pct=${1:-0}
  local warn=${2:-70}
  local crit=${3:-90}
  if [[ $pct -ge $crit ]]; then
    printf '%b%3d%%%b' "$RED" "$pct" "$NC"
  elif [[ $pct -ge $warn ]]; then
    printf '%b%3d%%%b' "$YELLOW" "$pct" "$NC"
  else
    printf '%b%3d%%%b' "$GREEN" "$pct" "$NC"
  fi
}

# Format KB/s as human-readable throughput
format_rate() {
  local kbs=${1:-0}
  if [[ $kbs -ge 1024 ]]; then
    echo "$((kbs / 1024)) MB/s"
  else
    echo "${kbs} KB/s"
  fi
}

cmd_dashboard() {
  check_token
  local tmpdir
  tmpdir=$(mktemp -d)

  # Enter alternate screen buffer and hide cursor
  tput smcup 2>/dev/null || true
  tput civis 2>/dev/null || true
  tput clear 2>/dev/null || true

  _dashboard_cleanup() {
    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
    rm -rf "$tmpdir"
    kill "$(jobs -p)" 2>/dev/null || true
  }
  trap '_dashboard_cleanup' RETURN
  trap '_dashboard_cleanup; exit 0' INT TERM

  # Track previous disk sector counts and timestamps per builder for rate averaging
  declare -A prev_dr prev_dw prev_ts

  while true; do
    local cols
    cols=$(tput cols 2>/dev/null || echo 100)

    # Fetch running builders from Hetzner API
    local builders_json
    builders_json=$(hcloud server list -o json 2>/dev/null || echo '[]')

    local -a names=() ips=()
    while IFS='|' read -r name ip; do
      [[ -n "$name" ]] || continue
      names+=("$name")
      ips+=("$ip")
    done < <(echo "$builders_json" | jaq -r\
      '.[] | select(.name | test("^(big-)?builder-")) | select(.status == "running") | "\(.name)|\(.public_net.ipv4.ip)"' \
      2>/dev/null | sort)

    local count=${#names[@]}

    # Position cursor at top-left for flicker-free redraw
    tput cup 0 0

    # Title
    local timestamp
    timestamp=$(date +%H:%M:%S)
    printf ' %b%s%b%*s%s' "$GREEN" "Builders Dashboard" "$NC" $((cols - 29)) "" "$timestamp"
    tput el; echo

    tput el; echo

    # Set up host key verification for all builder IPs
    if [[ $count -gt 0 ]]; then
      setup_host_verification "${ips[@]}"
    fi

    if [[ $count -eq 0 ]]; then
      echo " No active builders."
      tput el; echo
      printf ' [q] quit  [r] refresh'
      tput el; echo
      tput ed
    else
      # Collect stats from all builders in parallel
      rm -f "$tmpdir"/builder-* "$tmpdir"/big-builder-* 2>/dev/null || true
      local -a pids=()
      for i in "${!names[@]}"; do
        ( timeout 15 ssh -o ConnectTimeout=5 -o BatchMode=yes -o LogLevel=ERROR "${SSH_OPTS[@]}" \
            "remotebuild@${ips[$i]}" "$REMOTE_STATS_CMD" \
            > "$tmpdir/${names[$i]}" 2>/dev/null < /dev/null \
          || echo "ERROR" > "$tmpdir/${names[$i]}" ) &
        pids+=($!)
      done
      wait "${pids[@]}" 2>/dev/null || true

      # Table header
      printf ' %-16s %-16s %6s  %4s  %4s   %-20s  %-22s  %-14s %-6s %-8s %s' \
        "BUILDER" "IP" "BUILDS" "SSH" "CPU" "MEMORY" "DISK R/W" "/nix/store" "TUN" "CACHE Q" "SHUTDOWN"
      tput el; echo

      local sep
      sep=$(printf '%.0s' $(seq 1 $((cols - 2))))
      printf ' %s' "$sep"
      tput el; echo

      local total_builds=0 regular_count=0 big_count=0

      for i in "${!names[@]}"; do
        local data
        # Read last non-empty line (skip any SSH banners/MOTD/PAM output)
        data=$(grep -v '^[[:space:]]*$' "$tmpdir/${names[$i]}" 2>/dev/null | tail -1 || true)

        # Count by type
        if [[ "$(builder_type "${names[$i]}")" == "big" ]]; then
          big_count=$((big_count + 1))
        else
          regular_count=$((regular_count + 1))
        fi

        if [[ -z "$data" || "$data" == "ERROR" || "$data" != *"|"* ]]; then
          # Clear stale disk counters so next successful refresh doesn't produce negative rates
          unset "prev_dr[${names[$i]}]" "prev_dw[${names[$i]}]" "prev_ts[${names[$i]}]" 2>/dev/null || true
          printf ' %-16s %-16s  %b%s%b' "${names[$i]}" "${ips[$i]}" "$RED" "connection failed" "$NC"
          tput el; echo
          continue
        fi

        local builds cpu mu mt dr_sec dw_sec dst dsu dsp ssh_sess tun_stat q_pending q_done idle_count
        IFS='|' read -r builds cpu mu mt dr_sec dw_sec dst dsu dsp ssh_sess tun_stat q_pending q_done idle_count <<< "$data"
        builds=${builds:-0}; cpu=${cpu:-0}; mu=${mu:-0}; mt=${mt:-0}
        dr_sec=${dr_sec:-0}; dw_sec=${dw_sec:-0}; dst=${dst:-0}; dsu=${dsu:-0}; dsp=${dsp:-0}; ssh_sess=${ssh_sess:-0}; tun_stat=${tun_stat:-unknown}
        q_pending=${q_pending:-0}; q_done=${q_done:-0}; idle_count=${idle_count:-0}

        total_builds=$((total_builds + builds))

        # Compute disk I/O rates from cumulative sector deltas between refreshes
        local bname="${names[$i]}"
        local now_ts drk dwk
        now_ts=$(date +%s)
        drk=0; dwk=0
        if [[ -n "${prev_dr[$bname]:-}" ]]; then
          local elapsed=$(( now_ts - prev_ts[$bname] ))
          if [[ $elapsed -gt 0 ]]; then
            drk=$(( (dr_sec - prev_dr[$bname]) / 2 / elapsed ))
            dwk=$(( (dw_sec - prev_dw[$bname]) / 2 / elapsed ))
            # Clamp negative rates (stale/missing data from previous cycle)
            [[ $drk -lt 0 ]] && drk=0
            [[ $dwk -lt 0 ]] && dwk=0
          fi
        fi
        prev_dr[$bname]=$dr_sec
        prev_dw[$bname]=$dw_sec
        prev_ts[$bname]=$now_ts

        local mu_gb mt_gb mem_pct dsu_gb dst_gb dr_fmt dw_fmt
        mu_gb=$(format_kb "$mu")
        mt_gb=$(format_kb "$mt")
        mem_pct=0
        [[ $mt -gt 0 ]] && mem_pct=$((mu * 100 / mt))
        dsu_gb=$(format_kb "$dsu")
        dst_gb=$(format_kb "$dst")
        dr_fmt=$(format_rate "$drk")
        dw_fmt=$(format_rate "$dwk")

        printf ' %-16s %-16s %6s  %4s  ' "${names[$i]}" "${ips[$i]}" "$builds" "$ssh_sess"
        color_pct "$cpu"
        printf '   %5s/%s GB (' "$mu_gb" "$mt_gb"
        color_pct "$mem_pct"
        printf ')  %8s / %8s  %5s/%s GB (' "$dr_fmt" "$dw_fmt" "$dsu_gb" "$dst_gb"
        color_pct "$dsp" 75 90
        printf ')  '
        if [[ "$tun_stat" == "active" ]]; then
          printf '%b%-6s%b' "$GREEN" "$tun_stat" "$NC"
        else
          printf '%b%-6s%b' "$YELLOW" "$tun_stat" "$NC"
        fi
        if [[ "$q_pending" -gt 0 ]]; then
          printf ' %-8s' "$(printf '%b%s%b/%s' "$YELLOW" "$q_pending" "$NC" "$q_done")"
        else
          printf ' %-8s' "$q_pending/$q_done"
        fi
        # Auto-shutdown countdown
        local remaining=$(( 15 - idle_count ))
        if [[ $builds -gt 0 ]]; then
          printf ' %bactive%b' "$GREEN" "$NC"
        elif [[ $remaining -le 2 ]]; then
          printf ' %b%sm left%b' "$RED" "$remaining" "$NC"
        elif [[ $remaining -le 5 ]]; then
          printf ' %b%sm left%b' "$YELLOW" "$remaining" "$NC"
        else
          printf ' %b%sm left%b' "$GREEN" "$remaining" "$NC"
        fi
        tput el; echo
      done

      # Bottom separator
      printf ' %s' "$sep"
      tput el; echo

      # Footer with totals, costs, and local cache queue
      local regular_cost big_cost total_cost
      regular_cost=$(echo "$regular_count * $REGULAR_HOURLY_COST" | bc)
      big_cost=$(echo "$big_count * $BIG_HOURLY_COST" | bc)
      total_cost=$(echo "$regular_cost + $big_cost" | bc)
      local local_pending=0 local_done=0
      [[ -d /var/lib/cache-upload-queue/pending ]] && local_pending=$(find /var/lib/cache-upload-queue/pending -maxdepth 1 -type f 2>/dev/null | wc -l)
      [[ -d /var/lib/cache-upload-queue/done ]] && local_done=$(find /var/lib/cache-upload-queue/done -maxdepth 1 -type f 2>/dev/null | wc -l)
      local footer
      footer=$(printf '%d regular + %d big | %d builds | est %s/hr | local queue: %d pending, %d uploaded' "$regular_count" "$big_count" "$total_builds" "$total_cost" "$local_pending" "$local_done")
      local controls="[q] quit  [r] refresh"
      local pad=$((cols - ${#footer} - ${#controls} - 4))
      [[ $pad -lt 2 ]] && pad=2
      printf ' %s%*s%s' "$footer" "$pad" "" "$controls"
      tput el; echo

      tput ed
    fi

    # Wait for keypress or 3-second timeout
    if read -rsn1 -t 3 key 2>/dev/null; then
      case "$key" in
        q|Q) break ;;
        r|R) continue ;;
      esac
    fi
  done
}

# Main
case "${1:-help}" in
  list)
    cmd_list
    ;;
  status)
    cmd_status
    ;;
  dashboard)
    cmd_dashboard
    ;;
  check)
    [[ -z "${2:-}" ]] && { echo "Usage: $SCRIPT_NAME check <name|N>  (e.g., 1, builder-1, big-builder-1)"; exit 1; }
    cmd_check "$(normalize_name "$2")"
    ;;
  create)
    [[ -z "${2:-}" ]] && { echo "Usage: $SCRIPT_NAME create <name|N>  (e.g., 1, builder-1, big-builder-1)"; exit 1; }
    _create_name="$(normalize_name "$2")"
    if ! is_builder_name "$_create_name"; then
      echo -e "${RED}Error: Invalid builder name '$2'. Use N, builder-N, or big-builder-N${NC}" >&2
      exit 1
    fi
    cmd_create "$_create_name"
    ;;
  destroy)
    if [[ "${2:-}" == "-a" ]]; then
      cmd_destroy_all
    else
      [[ -z "${2:-}" ]] && { echo "Usage: $SCRIPT_NAME destroy <name|N|-a>  (e.g., 1, builder-1, big-builder-1, -a for all)"; exit 1; }
      cmd_destroy "$(normalize_name "$2")"
    fi
    ;;
  destroy-all)
    cmd_destroy_all
    ;;
  debug-stats)
    [[ -z "${2:-}" ]] && { echo "Usage: $SCRIPT_NAME debug-stats <name|N>"; exit 1; }
    _ds_name="$(normalize_name "$2")"
    check_token
    _ds_ip=$(hcloud server describe "$_ds_name" -o json 2>/dev/null | jaq -r '.public_net.ipv4.ip')
    [[ -z "$_ds_ip" || "$_ds_ip" == "null" ]] && { echo -e "${RED}Builder $_ds_name not found${NC}"; exit 1; }
    setup_host_verification "$_ds_ip"
    echo "=== Raw SSH output (with stderr) ==="
    echo "--- Command: ssh remotebuild@$_ds_ip (port 3098) ---"
    _ds_exit=0
    timeout 15 ssh -o ConnectTimeout=5 -o BatchMode=yes "${SSH_OPTS[@]}" \
      "remotebuild@$_ds_ip" "$REMOTE_STATS_CMD" 2>&1 || _ds_exit=$?
    echo ""
    echo "=== Exit code: $_ds_exit ==="
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    echo "Unknown command: $1"
    show_help
    exit 1
    ;;
esac
