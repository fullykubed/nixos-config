#!/usr/bin/env bash
# modules/common/binary-cache/cache-cli.sh
# CLI tool for managing the Hetzner Cloud niks3 binary cache server
# Only one cache server may exist at a time.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
TOKEN_FILE="/run/agenix/hetzner-api-token"
SIGNING_KEY_FILE="/run/agenix/cache-signing-key"
R2_ACCESS_KEY_FILE="/run/agenix/r2-access-key"
R2_SECRET_KEY_FILE="/run/agenix/r2-secret-key"
NIKS3_API_TOKEN_FILE="/run/agenix/niks3-api-token"
PUBKEY_FILE="/etc/ssh/cache-key.pub"
HOST_KEY_FILE="/run/agenix/cache-host-key"
HOST_PUBKEY_FILE="/etc/ssh/cache-host-key.pub"
SERVER_NAME="cache-1"
SERVER_TYPE="${CACHE_SERVER_TYPE:-cpx22}"
LOCATION="${CACHE_LOCATION:-hel1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Base SSH options (host key verification added dynamically per IP)
SSH_BASE_OPTS=(-i /root/.ssh/cache-key -p 3099)
SSH_OPTS=() # populated by setup_host_verification

# Temporary known hosts file for host key verification
_KNOWN_HOSTS_TMP=""
_cleanup_known_hosts() {
  [[ -n "$_KNOWN_HOSTS_TMP" ]] && rm -f "$_KNOWN_HOSTS_TMP"
}
trap '_cleanup_known_hosts' EXIT

# Resolve the latest cache snapshot by label (or use explicit override)
resolve_snapshot_id() {
  if [[ -n "${HETZNER_CACHE_SNAPSHOT:-}" ]]; then
    echo "$HETZNER_CACHE_SNAPSHOT"
    return
  fi
  local id
  id=$(hcloud image list -t snapshot -l type=cache -o json 2>/dev/null \
    | jq -r 'sort_by(.created) | last | .id // empty')
  if [[ -z "$id" ]]; then
    echo -e "${RED}Error: No snapshot found with label type=cache${NC}" >&2
    echo "Upload a cache image first, or set HETZNER_CACHE_SNAPSHOT." >&2
    exit 1
  fi
  echo "$id"
}

# Find the existing cache server (by label). Sets CACHE_NAME and CACHE_IP.
# Returns 1 if no cache server exists.
find_cache_server() {
  local server_json
  server_json=$(hcloud server list -l cache=true -o json 2>/dev/null)
  CACHE_NAME=$(echo "$server_json" | jq -r '.[0].name // empty')
  CACHE_IP=$(echo "$server_json" | jq -r '.[0].public_net.ipv4.ip // empty')
  CACHE_STATUS=$(echo "$server_json" | jq -r '.[0].status // empty')
  [[ -n "$CACHE_NAME" ]]
}

# Set up host key verification for a specific cache server IP.
# Generates a temporary known_hosts with [ip]:3099 mapped to our known host public key.
setup_host_verification() {
  local ip="$1"
  if [[ ! -f "$HOST_PUBKEY_FILE" ]]; then
    echo -e "${RED}Error: Host public key not found at $HOST_PUBKEY_FILE${NC}" >&2
    echo "Cannot verify cache server identity without the host public key." >&2
    exit 1
  fi
  _KNOWN_HOSTS_TMP=$(mktemp)
  echo "[${ip}]:3099 $(cat "$HOST_PUBKEY_FILE")" > "$_KNOWN_HOSTS_TMP"
  SSH_OPTS=("${SSH_BASE_OPTS[@]}" -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$_KNOWN_HOSTS_TMP")
}

show_help() {
  cat <<EOF
Usage: $SCRIPT_NAME <command>

Only one cache server may exist at a time.

Commands:
  status            Show cache server state (running/stopped, IP, uptime)
  create            Create the cache server
  destroy           Destroy the cache server (requires confirmation)
  check             Check SSH connectivity and niks3 health
  enqueue all       Enqueue all paths in the current system closure for upload
  help              Show this help message

Examples:
  $SCRIPT_NAME status
  $SCRIPT_NAME create
  $SCRIPT_NAME check
  $SCRIPT_NAME destroy
  $SCRIPT_NAME enqueue all
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

cmd_status() {
  check_token

  echo -e "${GREEN}Cache Server Status${NC}"
  echo "===================="
  echo ""

  if find_cache_server; then
    echo "Name:   $CACHE_NAME"
    echo "IP:     $CACHE_IP"
    echo "Status: $CACHE_STATUS"
  else
    echo "No cache server running."
  fi
}

cmd_create() {
  check_token

  # Enforce single cache server
  if find_cache_server; then
    echo -e "${RED}Error: Cache server already exists ($CACHE_NAME at $CACHE_IP, status: $CACHE_STATUS)${NC}" >&2
    echo "Destroy it first with: $SCRIPT_NAME destroy" >&2
    return 1
  fi

  local snapshot_id
  snapshot_id=$(resolve_snapshot_id)

  # Verify secret files exist
  if [[ ! -f "$SIGNING_KEY_FILE" ]]; then
    echo -e "${RED}Error: Cache signing key not found at $SIGNING_KEY_FILE${NC}" >&2
    exit 1
  fi

  if [[ ! -f "$R2_ACCESS_KEY_FILE" ]]; then
    echo -e "${RED}Error: R2 access key not found at $R2_ACCESS_KEY_FILE${NC}" >&2
    exit 1
  fi

  if [[ ! -f "$R2_SECRET_KEY_FILE" ]]; then
    echo -e "${RED}Error: R2 secret key not found at $R2_SECRET_KEY_FILE${NC}" >&2
    exit 1
  fi

  if [[ ! -f "$NIKS3_API_TOKEN_FILE" ]]; then
    echo -e "${RED}Error: niks3 API token not found at $NIKS3_API_TOKEN_FILE${NC}" >&2
    exit 1
  fi

  # Verify SSH key files exist
  if [[ ! -f "$PUBKEY_FILE" ]]; then
    echo -e "${RED}Error: SSH public key not found at $PUBKEY_FILE${NC}" >&2
    exit 1
  fi
  if [[ ! -f "$HOST_KEY_FILE" ]]; then
    echo -e "${RED}Error: Host key not found at $HOST_KEY_FILE${NC}" >&2
    exit 1
  fi

  echo -e "${YELLOW}Creating cache server $SERVER_NAME (${SERVER_TYPE})...${NC}"

  # Read secrets and SSH keys for injection
  local signing_key r2_access_key r2_secret_key niks3_token hcloud_token
  signing_key=$(cat "$SIGNING_KEY_FILE")
  r2_access_key=$(cat "$R2_ACCESS_KEY_FILE")
  r2_secret_key=$(cat "$R2_SECRET_KEY_FILE")
  niks3_token=$(cat "$NIKS3_API_TOKEN_FILE")
  hcloud_token=$(cat "$TOKEN_FILE")

  local ssh_pubkey host_privkey host_pubkey
  ssh_pubkey=$(cat "$PUBKEY_FILE")
  host_privkey=$(cat "$HOST_KEY_FILE")
  host_pubkey=$(cat "$HOST_PUBKEY_FILE")

  # Build cloud-init user-data to inject secrets and SSH keys
  local user_data_file
  user_data_file=$(mktemp)
  trap 'rm -f "$user_data_file"' RETURN

  cat > "$user_data_file" <<EOF
#cloud-config
ssh_pwauth: false
chpasswd:
  expire: false
write_files:
  - path: /run/agenix/hetzner-api-token
    permissions: '0400'
    content: |
      $hcloud_token
  - path: /run/niks3-secrets/signing-key
    permissions: '0400'
    owner: niks3:niks3
    content: |
      ${signing_key//$'\n'/$'\n'      }
  - path: /run/niks3-secrets/r2-access-key
    permissions: '0400'
    owner: niks3:niks3
    content: |
      $r2_access_key
  - path: /run/niks3-secrets/r2-secret-key
    permissions: '0400'
    owner: niks3:niks3
    content: |
      $r2_secret_key
  - path: /run/niks3-secrets/api-token
    permissions: '0400'
    owner: niks3:niks3
    content: |
      $niks3_token
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
runcmd:
  - systemctl restart sshd.service
  - systemctl restart niks3.service
EOF

  hcloud server create \
    --name "$SERVER_NAME" \
    --type "$SERVER_TYPE" \
    --image "$snapshot_id" \
    --location "$LOCATION" \
    --label "cache=true" \
    --label "type=cache" \
    --user-data-from-file "$user_data_file" \
    --poll-interval 2s

  echo -e "${GREEN}Created cache server $SERVER_NAME${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Wait 30-60 seconds for cloud-init to complete"
  echo "  2. Run: $SCRIPT_NAME check"
}

cmd_destroy() {
  check_token

  if ! find_cache_server; then
    echo "No cache server to destroy."
    return
  fi

  echo -e "${RED}WARNING: This will destroy the cache server $CACHE_NAME ($CACHE_IP)${NC}"
  echo "The cache data in R2 will remain intact."
  echo ""
  read -r -p "Type 'yes' to confirm: " confirm

  if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    return
  fi

  echo -e "${YELLOW}Destroying cache server $CACHE_NAME...${NC}"
  hcloud server delete "$CACHE_NAME"
  echo -e "${GREEN}Destroyed cache server $CACHE_NAME${NC}"
}

cmd_check() {
  check_token

  if ! find_cache_server; then
    echo -e "${RED}No cache server found${NC}"
    return 1
  fi

  echo -e "${YELLOW}Checking cache server $CACHE_NAME...${NC}"
  echo -e "IP: ${GREEN}${CACHE_IP}${NC}"
  echo "Status: $CACHE_STATUS"

  if [[ "$CACHE_STATUS" != "running" ]]; then
    echo -e "${RED}Server is not running${NC}"
    return 1
  fi

  # Set up host key verification for this IP
  setup_host_verification "$CACHE_IP"

  # Check SSH connectivity with verbose debug on failure
  echo -n "SSH connectivity: "
  local ssh_err ssh_exit
  ssh_err=$(mktemp)
  ssh -o ConnectTimeout=10 -o BatchMode=yes "${SSH_OPTS[@]}" "root@$CACHE_IP" "true" 2>"$ssh_err" && ssh_exit=0 || ssh_exit=$?
  if [[ "$ssh_exit" -eq 0 ]]; then
    echo -e "${GREEN}OK${NC}"
    rm -f "$ssh_err"
  else
    echo -e "${RED}FAILED${NC}"
    echo ""
    echo -e "  ${RED}--- SSH debug ---${NC}"
    echo -e "  Exit code: $ssh_exit"
    echo -e "  Target:    root@${CACHE_IP}:3099"
    echo -e "  Key:       /root/.ssh/cache-key"

    # Key file checks
    if [[ -f /root/.ssh/cache-key ]]; then
      echo -e "  Key file:  ${GREEN}exists${NC} ($(stat -c '%A' /root/.ssh/cache-key))"
    else
      echo -e "  Key file:  ${RED}MISSING${NC}"
    fi

    # Host key verification info
    if [[ -n "$_KNOWN_HOSTS_TMP" ]]; then
      echo -e "  Host key:  verified via $_KNOWN_HOSTS_TMP"
    else
      echo -e "  Host key:  ${YELLOW}verification disabled${NC}"
    fi

    # SSH stderr (the actual error messages)
    if [[ -s "$ssh_err" ]]; then
      echo ""
      echo -e "  ${RED}--- SSH stderr ---${NC}"
      sed 's/^/  /' "$ssh_err"
    fi

    echo ""

    # Port reachability check
    echo -n "  Port 3099: "
    if timeout 3 bash -c "echo >/dev/tcp/$CACHE_IP/3099" 2>/dev/null; then
      echo -e "${GREEN}reachable${NC} (SSH handshake or auth failed)"
    else
      echo -e "${RED}NOT reachable${NC} (firewall, sshd not running, or cloud-init still in progress)"
    fi

    # Retry with -vvv to capture full debug trace
    echo ""
    echo -e "  ${YELLOW}--- Verbose SSH trace ---${NC}"
    (ssh -vvv -o ConnectTimeout=10 -o BatchMode=yes "${SSH_OPTS[@]}" "root@$CACHE_IP" "true" 2>&1 || true) \
      | grep -iE '(debug1:|error|denied|refused|timeout|closed|banner|identity|offering|authentic|host key)' \
      | head -30 \
      | sed 's/^/  /'

    rm -f "$ssh_err"
    return 1
  fi

  # Check services (single SSH call)
  echo -n "Services: "
  local svc_output
  if svc_output=$(ssh -o ConnectTimeout=10 "${SSH_OPTS[@]}" "root@$CACHE_IP" '
    for svc in niks3 postgresql; do
      st=$(systemctl is-active "${svc}.service" 2>/dev/null) || true
      printf "%s=%s\n" "$svc" "$st"
    done
  ' 2>/dev/null); then
    local all_ok=true
    local failed_svcs=()
    while IFS='=' read -r svc st; do
      svc="${svc// /}"
      st="${st// /}"
      [[ -z "$svc" ]] && continue
      if [[ "$st" == "active" ]]; then
        printf '%s ' "$svc"
      else
        printf '%b%s(%s)%b ' "$RED" "$svc" "$st" "$NC"
        failed_svcs+=("$svc")
        all_ok=false
      fi
    done <<< "$svc_output"
    if [[ "$all_ok" == "true" ]]; then
      echo -e "${GREEN}OK${NC}"
    else
      echo ""
      # Show detailed status and recent logs for failed services
      for svc in "${failed_svcs[@]}"; do
        echo ""
        echo -e "${RED}--- $svc.service ---${NC}"
        ssh -o ConnectTimeout=10 "${SSH_OPTS[@]}" "root@$CACHE_IP" "
          systemctl status ${svc}.service --no-pager -l 2>&1 | head -20
          echo ''
          echo '--- Recent logs ---'
          journalctl -u ${svc}.service --no-pager -n 30 2>&1
        " 2>/dev/null || echo "  Failed to retrieve details"
      done
      return 1
    fi
  else
    echo -e "${RED}FAILED (SSH error)${NC}"
    return 1
  fi

  # Gather all diagnostics in a single SSH call
  local diag_output
  diag_output=$(ssh -o ConnectTimeout=10 "${SSH_OPTS[@]}" "root@$CACHE_IP" '
    echo "=== UPTIME ==="
    awk "{d=int(\$1/86400); h=int(\$1%86400/3600); m=int(\$1%3600/60); \
      printf \"%dd %dh %dm\n\", d, h, m}" /proc/uptime 2>/dev/null || echo "unknown"

    echo "=== CLOUD_INIT ==="
    if command -v cloud-init >/dev/null 2>&1; then
      cloud-init status 2>/dev/null || echo "status unknown"
    elif [ -d /var/lib/cloud/instance ]; then
      echo "done"
    else
      echo "not configured"
    fi
    echo "---errors---"
    if [ -f /var/lib/cloud/data/result.json ]; then
      errs=$(jq -r '.v1.errors[]' /var/lib/cloud/data/result.json 2>/dev/null)
      if [ -n "$errs" ]; then
        echo "$errs"
      else
        echo "none"
      fi
    else
      echo "none"
    fi

    echo "=== SECRETS ==="
    for f in /run/niks3-secrets/r2-access-key /run/niks3-secrets/r2-secret-key /run/niks3-secrets/api-token /run/niks3-secrets/signing-key; do
      name=$(basename "$f")
      if [ ! -f "$f" ]; then
        echo "$name: MISSING"
      elif [ ! -s "$f" ]; then
        echo "$name: EMPTY"
      else
        owner=$(stat -c "%U:%G" "$f" 2>/dev/null || echo "unknown")
        perms=$(stat -c "%a" "$f" 2>/dev/null || echo "unknown")
        echo "$name: ok (owner=$owner mode=$perms)"
      fi
    done

    echo "=== POSTGRES ==="
    if systemctl is-active postgresql.service >/dev/null 2>&1; then
      su -s /bin/sh postgres -c "psql -d niks3 -c \"SELECT 1\" -t -A" 2>&1 && echo "db_ok" || echo "db_error"
    else
      echo "not running"
    fi

    echo "=== HEALTH ==="
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:5751/health 2>/dev/null || echo "000")
    echo "$http_code"
    if [ "$http_code" != "200" ]; then
      echo "---body---"
      curl -s --max-time 5 http://localhost:5751/health 2>&1 || echo "connection failed"
    fi

    echo "=== PORTS ==="
    ss -tlnp "sport = :5751 or sport = :5432" 2>/dev/null || echo "ss not available"

    echo "=== DISK ==="
    df -h / --output=size,used,avail,pcent | tail -1

    echo "=== MEMORY ==="
    free -h | awk "/^Mem:/ {printf \"%s used / %s total (%s available)\n\", \$3, \$2, \$7}"

    echo "=== FAILED_UNITS ==="
    failed=$(systemctl --failed --no-legend --no-pager 2>/dev/null)
    if [ -n "$failed" ]; then
      echo "$failed"
    else
      echo "none"
    fi

    echo "=== OOM ==="
    oom=$(dmesg 2>/dev/null | grep -i "killed process" | tail -5)
    if [ -n "$oom" ]; then
      echo "$oom"
    else
      echo "none"
    fi

    echo "=== END ==="
  ' 2>/dev/null)

  if [[ -z "$diag_output" ]]; then
    echo -e "${RED}Failed to gather diagnostics via SSH${NC}"
    return 1
  fi

  # Parse and display diagnostics
  local has_errors=false

  # Uptime
  local uptime_val
  uptime_val=$(echo "$diag_output" | sed -n '/=== UPTIME ===/,/=== /{/===/d;p}' | head -1)
  echo "Uptime: $uptime_val"

  # Cloud-init
  echo -n "Cloud-init: "
  local ci_status
  ci_status=$(echo "$diag_output" | sed -n '/=== CLOUD_INIT ===/,/---errors---/{/===/d;/---errors---/d;p}' | head -1)
  local ci_errors
  ci_errors=$(echo "$diag_output" | sed -n '/---errors---/,/=== /{/---errors---/d;/===/d;p}')
  if echo "$ci_status" | grep -q "done"; then
    echo -e "${GREEN}done${NC}"
  else
    echo -e "${YELLOW}${ci_status}${NC}"
  fi
  if [[ -n "$ci_errors" ]] && ! echo "$ci_errors" | grep -q "^none$"; then
    echo -e "  ${RED}Cloud-init errors:${NC}"
    while IFS= read -r line; do
      echo -e "    ${RED}${line}${NC}"
    done <<< "$ci_errors"
    has_errors=true
  fi

  # Secrets
  echo -n "Secrets: "
  local secrets_section
  secrets_section=$(echo "$diag_output" | sed -n '/=== SECRETS ===/,/=== /{/===/d;p}')
  if echo "$secrets_section" | grep -qE "(MISSING|EMPTY)"; then
    echo -e "${RED}FAILED${NC}"
    echo "$secrets_section" | while read -r line; do
      if echo "$line" | grep -qE "(MISSING|EMPTY)"; then
        echo -e "  ${RED}$line${NC}"
      else
        echo "  $line"
      fi
    done
    has_errors=true
  else
    echo -e "${GREEN}OK${NC}"
  fi

  # PostgreSQL
  echo -n "PostgreSQL: "
  local pg_section
  pg_section=$(echo "$diag_output" | sed -n '/=== POSTGRES ===/,/=== /{/===/d;p}')
  if echo "$pg_section" | grep -q "db_ok"; then
    echo -e "${GREEN}OK${NC}"
  else
    echo -e "${RED}FAILED${NC}"
    # shellcheck disable=SC2001
    echo "$pg_section" | sed 's/^/  /'
    has_errors=true
  fi

  # HTTP health (niks3 on :5751)
  echo -n "niks3 health: "
  local health_section http_code health_body
  health_section=$(echo "$diag_output" | sed -n '/=== HEALTH ===/,/=== /{/===/d;p}')
  http_code=$(echo "$health_section" | head -1 | tr -d '[:space:]')
  if [[ "$http_code" == "200" ]]; then
    echo -e "${GREEN}OK${NC}"
  elif [[ "$http_code" == "000" ]]; then
    echo -e "${RED}FAILED (connection refused)${NC}"
    has_errors=true
  else
    echo -e "${RED}HTTP $http_code${NC}"
    health_body=$(echo "$health_section" | sed -n '/---body---/,$ {/---body---/d;p}')
    if [[ -n "$health_body" ]]; then
      echo -e "  ${RED}Response: ${health_body}${NC}"
    fi
    has_errors=true
  fi

  # Disk
  echo -n "Disk space: "
  local disk_section
  disk_section=$(echo "$diag_output" | sed -n '/=== DISK ===/,/=== /{/===/d;p}' | head -1)
  if [[ -n "$disk_section" ]]; then
    local d_size _d_used d_avail d_pct
    read -r d_size _d_used d_avail d_pct <<< "$disk_section"
    echo -e "${GREEN}${d_avail} available / ${d_size} total (${d_pct} used)${NC}"
  else
    echo -e "${YELLOW}SKIPPED${NC}"
  fi

  # Memory
  echo -n "Memory: "
  local mem_section
  mem_section=$(echo "$diag_output" | sed -n '/=== MEMORY ===/,/=== /{/===/d;p}' | head -1)
  echo -e "${GREEN}${mem_section}${NC}"

  # Show additional diagnostics only on errors
  if [[ "$has_errors" == "true" ]]; then
    echo ""

    # Ports
    echo -e "${YELLOW}--- Listening ports ---${NC}"
    echo "$diag_output" | sed -n '/=== PORTS ===/,/=== /{/===/d;p}'

    # Failed units
    local failed_units
    failed_units=$(echo "$diag_output" | sed -n '/=== FAILED_UNITS ===/,/=== /{/===/d;p}')
    if [[ -n "$failed_units" ]] && ! echo "$failed_units" | grep -q "^none$"; then
      echo ""
      echo -e "${RED}--- Failed systemd units ---${NC}"
      echo "$failed_units"
    fi

    # OOM
    local oom_section
    oom_section=$(echo "$diag_output" | sed -n '/=== OOM ===/,/=== /{/===/d;p}')
    if [[ -n "$oom_section" ]] && ! echo "$oom_section" | grep -q "^none$"; then
      echo ""
      echo -e "${RED}--- OOM events ---${NC}"
      echo "$oom_section"
    fi

    return 1
  fi

  echo -e "${GREEN}Cache server $CACHE_NAME is healthy${NC}"
}

QUEUE_DIR="/var/lib/cache-upload-queue"

cmd_enqueue() {
  local subcmd="${1:-}"
  if [[ "$subcmd" != "all" ]]; then
    echo "Usage: $SCRIPT_NAME enqueue all [STORE_PATH]"
    echo ""
    echo "Enqueue all paths in a store closure for cache upload."
    echo "Defaults to /run/current-system if no path is given."
    exit 1
  fi

  local system_path="${2:-/run/current-system}"
  local pending_dir="$QUEUE_DIR/pending"
  local done_dir="$QUEUE_DIR/done"

  if [[ ! -e "$system_path" ]]; then
    echo -e "${RED}Error: $system_path does not exist${NC}" >&2
    exit 1
  fi

  mkdir -p "$pending_dir" "$done_dir"

  echo -e "${YELLOW}Querying closure of $system_path...${NC}"
  local paths total enqueued=0 skipped=0
  paths=$(nix-store -qR "$system_path")
  total=$(echo "$paths" | wc -l)

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    local hash
    hash=$(basename "$path" | cut -d- -f1)

    if [[ -f "$done_dir/$hash" ]] || [[ -f "$pending_dir/$hash" ]]; then
      skipped=$((skipped + 1))
      continue
    fi

    echo "$path" > "$pending_dir/$hash"
    enqueued=$((enqueued + 1))
  done <<< "$paths"

  echo -e "${GREEN}Closure:  $total paths${NC}"
  echo -e "${GREEN}Enqueued: $enqueued new${NC}"
  echo "Skipped:  $skipped (already queued or uploaded)"
}

# Main
case "${1:-help}" in
  status)
    cmd_status
    ;;
  create)
    cmd_create
    ;;
  destroy)
    cmd_destroy
    ;;
  check)
    cmd_check
    ;;
  enqueue)
    shift
    cmd_enqueue "$@"
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    if [[ -n "${1:-}" ]]; then
      echo "Unknown command: $1"
    fi
    show_help
    exit 1
    ;;
esac
