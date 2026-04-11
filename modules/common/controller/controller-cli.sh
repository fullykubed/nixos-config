#!/usr/bin/env bash
# modules/common/controller/controller-cli.sh
# CLI tool for managing the Hetzner Cloud controller server
# Only one controller server may exist at a time.
# shellcheck disable=SC2016,SC2288 # jaq expressions inside heredocs confuse shellcheck

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
TOKEN_FILE="/run/agenix/hetzner-api-token"
SIGNING_KEY_FILE="/run/agenix/cache-signing-key"
R2_ACCESS_KEY_FILE="/run/agenix/r2-access-key"
R2_SECRET_KEY_FILE="/run/agenix/r2-secret-key"
NIKS3_API_TOKEN_FILE="/run/agenix/niks3-api-token"
VOLUME_KEY_FILE="/run/agenix/controller-volume-key"
PUBKEY_FILE="/etc/ssh/cache-key.pub"
HOST_KEY_FILE="/run/agenix/cache-host-key"
HOST_PUBKEY_FILE="/etc/ssh/cache-host-key.pub"
CROC_RELAY_PASS_FILE="/run/agenix/croc-relay-password"
SERVER_NAME="controller-1"
SERVER_TYPE="${CONTROLLER_SERVER_TYPE:-cpx22}"
LOCATION="${CONTROLLER_LOCATION:-hel1}"
VOLUME_NAME="controller-data"
VOLUME_SIZE="10"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Base SSH options (host key verification added dynamically per IP)
SSH_BASE_OPTS=(-i /root/.ssh/cache-key -o IdentitiesOnly=yes -p 3099)
SSH_OPTS=() # populated by setup_host_verification

# Temporary known hosts file for host key verification
_KNOWN_HOSTS_TMP=""
_cleanup_known_hosts() {
  [[ -n "$_KNOWN_HOSTS_TMP" ]] && rm -f "$_KNOWN_HOSTS_TMP"
}
trap '_cleanup_known_hosts' EXIT

# Resolve the latest controller snapshot by label (or use explicit override)
resolve_snapshot_id() {
  if [[ -n "${HETZNER_CONTROLLER_SNAPSHOT:-}" ]]; then
    echo "$HETZNER_CONTROLLER_SNAPSHOT"
    return
  fi
  local id
  id=$(hcloud image list -t snapshot -l type=controller -o json 2>/dev/null \
    | jaq -r 'if . == null or length == 0 then empty else sort_by(.created) | last | .id end')
  if [[ -z "$id" ]]; then
    echo -e "${RED}Error: No snapshot found with label type=controller${NC}" >&2
    echo "Upload a controller image first, or set HETZNER_CONTROLLER_SNAPSHOT." >&2
    exit 1
  fi
  echo "$id"
}

# Find the existing controller server (by label). Sets FOUND_NAME and FOUND_IP.
# Returns 1 if no controller server exists.
find_server() {
  local server_json
  server_json=$(hcloud server list -l controller=true -o json 2>/dev/null)
  if [[ "$(echo "$server_json" | jaq 'if . == null then 0 else length end')" == "0" ]]; then
    return 1
  fi
  FOUND_NAME=$(echo "$server_json" | jaq -r '.[0].name // empty')
  FOUND_IP=$(echo "$server_json" | jaq -r '.[0].public_net.ipv4.ip // empty')
  FOUND_STATUS=$(echo "$server_json" | jaq -r '.[0].status // empty')
  [[ -n "$FOUND_NAME" ]]
}

# Find the persistent data volume. Sets VOLUME_ID, VOLUME_STATUS, VOLUME_SERVER.
# Returns 1 if no volume exists.
find_volume() {
  local vol_json vol
  vol_json=$(hcloud volume list -o json 2>/dev/null)
  vol=$(echo "$vol_json" | jaq "if . == null then null else [.[] | select(.name == \"$VOLUME_NAME\")] | .[0] end")
  VOLUME_ID=$(echo "$vol" | jaq -r '.id // empty')
  [[ -n "$VOLUME_ID" ]] || return 1
  VOLUME_STATUS=$(echo "$vol" | jaq -r '.status // empty')
  VOLUME_SERVER=$(echo "$vol" | jaq -r 'if .server then (.server | tostring) else "detached" end')
  VOLUME_SIZE_GB=$(echo "$vol" | jaq -r '.size // empty')
}

# Set up host key verification for a specific controller server IP.
# Generates a temporary known_hosts with [ip]:3099 mapped to our known host public key.
setup_host_verification() {
  local ip="$1"
  if [[ ! -f "$HOST_PUBKEY_FILE" ]]; then
    echo -e "${RED}Error: Host public key not found at $HOST_PUBKEY_FILE${NC}" >&2
    echo "Cannot verify controller server identity without the host public key." >&2
    exit 1
  fi
  _KNOWN_HOSTS_TMP=$(mktemp)
  echo "[${ip}]:3099 $(cat "$HOST_PUBKEY_FILE")" > "$_KNOWN_HOSTS_TMP"
  SSH_OPTS=("${SSH_BASE_OPTS[@]}" -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$_KNOWN_HOSTS_TMP")
}

# Wait for croc relay to be reachable on a given IP and port.
# Usage: wait_for_relay <ip> [port] [max_seconds]
wait_for_relay() {
  local ip="$1"
  local port="${2:-19009}"
  local max_seconds="${3:-120}"
  local attempt=0
  local max_attempts=$(( max_seconds / 5 ))

  echo -e "${YELLOW}Waiting for croc relay at $ip:$port...${NC}"
  while [[ $attempt -lt $max_attempts ]]; do
    if nc -z -w 2 "$ip" "$port" 2>/dev/null; then
      echo -e "${GREEN}Croc relay is reachable${NC}"
      return 0
    fi
    attempt=$(( attempt + 1 ))
    sleep 5
  done

  echo -e "${RED}Error: Croc relay not reachable after ${max_seconds}s${NC}" >&2
  return 1
}

show_help() {
  cat <<EOF
Usage: $SCRIPT_NAME <command>

Only one controller server may exist at a time.

Commands:
  status            Show controller server state (running/stopped, IP, uptime)
  create            Create the controller server
  destroy           Destroy the controller server (requires confirmation)
  ssh               SSH into the controller server
  check             Check SSH connectivity and niks3 health
  cache             Binary cache management (enqueue, etc.)
  cleanup           Delete old controller snapshots (keeps the latest)
  help              Show this help message

Examples:
  $SCRIPT_NAME status
  $SCRIPT_NAME create
  $SCRIPT_NAME ssh
  $SCRIPT_NAME ssh --no-verify            # skip host key check (pre-croc debugging)
  $SCRIPT_NAME ssh -- journalctl -u headscale -n 50
  $SCRIPT_NAME check
  $SCRIPT_NAME destroy
  $SCRIPT_NAME cache enqueue all
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

  echo -e "${GREEN}Controller Server Status${NC}"
  echo "===================="
  echo ""

  if find_server; then
    echo "Name:   $FOUND_NAME"
    echo "IP:     $FOUND_IP"
    echo "Status: $FOUND_STATUS"
  else
    echo "No controller server running."
  fi

  echo ""
  if find_volume; then
    echo "Volume: $VOLUME_NAME"
    echo "  ID:     $VOLUME_ID"
    echo "  Status: $VOLUME_STATUS"
    echo "  Server: $VOLUME_SERVER"
    echo "  Size:   ${VOLUME_SIZE_GB}GB"
  else
    echo "Volume: none"
  fi
}

cmd_create() {
  check_token

  # Enforce single controller server
  if find_server; then
    echo -e "${RED}Error: Controller server already exists ($FOUND_NAME at $FOUND_IP, status: $FOUND_STATUS)${NC}" >&2
    echo "Destroy it first with: $SCRIPT_NAME destroy" >&2
    return 1
  fi

  local snapshot_id
  snapshot_id=$(resolve_snapshot_id)

  # Verify secret files exist before proceeding
  if [[ ! -f "$SIGNING_KEY_FILE" ]]; then
    echo -e "${RED}Error: Signing key not found at $SIGNING_KEY_FILE${NC}" >&2
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

  local headscale_noise_key_file="/run/agenix/headscale-noise-key"
  if [[ ! -f "$headscale_noise_key_file" ]]; then
    echo -e "${RED}Error: Headscale noise key not found at $headscale_noise_key_file${NC}" >&2
    exit 1
  fi

  local cloudflare_token_file="/run/agenix/cloudflare-dns-token"
  if [[ ! -f "$cloudflare_token_file" ]]; then
    echo -e "${RED}Error: Cloudflare DNS token not found at $cloudflare_token_file${NC}" >&2
    exit 1
  fi

  if [[ ! -f "$CROC_RELAY_PASS_FILE" ]]; then
    echo -e "${RED}Error: croc relay password not found at $CROC_RELAY_PASS_FILE${NC}" >&2
    exit 1
  fi

  if [[ ! -f "$VOLUME_KEY_FILE" ]]; then
    echo -e "${RED}Error: Volume encryption key not found at $VOLUME_KEY_FILE${NC}" >&2
    exit 1
  fi

  if [[ ! -f "$PUBKEY_FILE" ]]; then
    echo -e "${RED}Error: SSH public key not found at $PUBKEY_FILE${NC}" >&2
    exit 1
  fi
  if [[ ! -f "$HOST_KEY_FILE" ]]; then
    echo -e "${RED}Error: Host key not found at $HOST_KEY_FILE${NC}" >&2
    exit 1
  fi

  # Read croc relay password and generate one-time transfer code
  local croc_relay_pass
  croc_relay_pass=$(cat "$CROC_RELAY_PASS_FILE")

  local croc_code
  croc_code=$(openssl rand -hex 16)

  # Set up temp file cleanup on function return
  local tmpdir user_data_file install_script_file
  tmpdir=$(mktemp -d)
  user_data_file="$tmpdir/user-data.yaml"
  install_script_file="$tmpdir/install-secrets.sh"
  trap 'rm -rf "$tmpdir"' RETURN

  local ssh_pubkey
  ssh_pubkey=$(cat "$PUBKEY_FILE")

  # Build minimal cloud-init: relay bootstrap + SSH public key for immediate access
  cat > "$user_data_file" <<EOF
#cloud-config
ssh_pwauth: false
chpasswd:
  expire: false
write_files:
  - path: /run/croc-relay-password
    permissions: '0444'
    content: |
      $croc_relay_pass
  - path: /run/croc-code
    permissions: '0400'
    content: |
      $croc_code
  - path: /root/.ssh/authorized_keys
    permissions: '0600'
    content: |
      $ssh_pubkey
EOF

  # Create persistent volume if it doesn't exist
  if find_volume; then
    echo "Volume $VOLUME_NAME already exists (ID: $VOLUME_ID)"
  else
    echo -e "${YELLOW}Creating persistent volume $VOLUME_NAME (${VOLUME_SIZE}GB)...${NC}"
    hcloud volume create --name "$VOLUME_NAME" --size "$VOLUME_SIZE" --location "$LOCATION"
    echo -e "${GREEN}Created volume $VOLUME_NAME${NC}"
  fi

  echo -e "${YELLOW}Creating controller server $SERVER_NAME (${SERVER_TYPE})...${NC}"

  hcloud server create \
    --name "$SERVER_NAME" \
    --type "$SERVER_TYPE" \
    --image "$snapshot_id" \
    --location "$LOCATION" \
    --volume "$VOLUME_NAME" \
    --label "controller=true" \
    --label "type=controller" \
    --user-data-from-file "$user_data_file" \
    --poll-interval 2s

  echo -e "${GREEN}Created controller server $SERVER_NAME${NC}"

  # Resolve the public IP of the newly created server
  if ! find_server; then
    echo -e "${RED}Error: Controller server not visible after creation${NC}" >&2
    return 1
  fi

  # Poll the croc relay port until reachable
  if ! wait_for_relay "$FOUND_IP" 19009 120; then
    return 1
  fi

  # Read all remaining secrets for the install script
  local signing_key r2_access_key r2_secret_key niks3_token hcloud_token
  signing_key=$(cat "$SIGNING_KEY_FILE")
  r2_access_key=$(cat "$R2_ACCESS_KEY_FILE")
  r2_secret_key=$(cat "$R2_SECRET_KEY_FILE")
  niks3_token=$(cat "$NIKS3_API_TOKEN_FILE")
  hcloud_token=$(cat "$TOKEN_FILE")

  local headscale_noise_key
  headscale_noise_key=$(cat "$headscale_noise_key_file")

  local cloudflare_token
  cloudflare_token=$(cat "$cloudflare_token_file")

  local volume_key
  volume_key=$(cat "$VOLUME_KEY_FILE")

  local ssh_pubkey host_privkey host_pubkey
  ssh_pubkey=$(cat "$PUBKEY_FILE")
  host_privkey=$(cat "$HOST_KEY_FILE")
  host_pubkey=$(cat "$HOST_PUBKEY_FILE")

  # Generate the install-secrets.sh script that the controller will execute.
  # All output is written in one grouped redirect to satisfy shellcheck SC2129.
  {
    printf '#!/usr/bin/env bash\nset -euo pipefail\n\n'
    printf 'mkdir -p /run/agenix /run/niks3-secrets /root/.ssh /etc/ssh\n\n'

    printf 'cat > /run/agenix/hetzner-api-token <<'"'"'SECRETEOF'"'"'\n%s\nSECRETEOF\n' "$hcloud_token"
    printf 'chmod 0400 /run/agenix/hetzner-api-token\nchown root:root /run/agenix/hetzner-api-token\n\n'

    printf 'cat > /run/niks3-secrets/signing-key <<'"'"'SECRETEOF'"'"'\n%s\nSECRETEOF\n' "$signing_key"
    printf 'chmod 0400 /run/niks3-secrets/signing-key\nchown niks3:niks3 /run/niks3-secrets/signing-key\n\n'

    printf 'cat > /run/niks3-secrets/r2-access-key <<'"'"'SECRETEOF'"'"'\n%s\nSECRETEOF\n' "$r2_access_key"
    printf 'chmod 0400 /run/niks3-secrets/r2-access-key\nchown niks3:niks3 /run/niks3-secrets/r2-access-key\n\n'

    printf 'cat > /run/niks3-secrets/r2-secret-key <<'"'"'SECRETEOF'"'"'\n%s\nSECRETEOF\n' "$r2_secret_key"
    printf 'chmod 0400 /run/niks3-secrets/r2-secret-key\nchown niks3:niks3 /run/niks3-secrets/r2-secret-key\n\n'

    printf 'cat > /run/niks3-secrets/api-token <<'"'"'SECRETEOF'"'"'\n%s\nSECRETEOF\n' "$niks3_token"
    printf 'chmod 0400 /run/niks3-secrets/api-token\nchown niks3:niks3 /run/niks3-secrets/api-token\n\n'

    printf 'cat > /run/headscale-noise-key <<'"'"'SECRETEOF'"'"'\n%s\nSECRETEOF\n' "$headscale_noise_key"
    printf 'chmod 0400 /run/headscale-noise-key\nchown root:root /run/headscale-noise-key\n\n'

    printf 'cat > /run/cloudflare-dns-token <<'"'"'SECRETEOF'"'"'\n%s\nSECRETEOF\n' "$cloudflare_token"
    printf 'chmod 0400 /run/cloudflare-dns-token\nchown root:root /run/cloudflare-dns-token\n\n'

    printf 'cat > /run/controller-volume-key <<'"'"'SECRETEOF'"'"'\n%s\nSECRETEOF\n' "$volume_key"
    printf 'chmod 0400 /run/controller-volume-key\nchown root:root /run/controller-volume-key\n\n'

    printf 'cat > /root/.ssh/authorized_keys <<'"'"'SECRETEOF'"'"'\n%s\nSECRETEOF\n' "$ssh_pubkey"
    printf 'chmod 0600 /root/.ssh/authorized_keys\nchown root:root /root/.ssh/authorized_keys\n\n'

    printf 'cat > /etc/ssh/ssh_host_ed25519_key <<'"'"'SECRETEOF'"'"'\n%s\nSECRETEOF\n' "$host_privkey"
    printf 'chmod 0600 /etc/ssh/ssh_host_ed25519_key\nchown root:root /etc/ssh/ssh_host_ed25519_key\n\n'

    printf 'cat > /etc/ssh/ssh_host_ed25519_key.pub <<'"'"'SECRETEOF'"'"'\n%s\nSECRETEOF\n' "$host_pubkey"
    printf 'chmod 0644 /etc/ssh/ssh_host_ed25519_key.pub\nchown root:root /etc/ssh/ssh_host_ed25519_key.pub\n'
  } > "$install_script_file"

  # Send the install script to the controller via croc
  echo -e "${YELLOW}Sending secrets to controller via croc...${NC}"
  local send_ok=false
  for attempt in $(seq 1 12); do
    if CROC_SECRET="$croc_code" croc --yes --quiet --relay "$FOUND_IP:19009" --pass "$croc_relay_pass" send "$install_script_file"; then
      send_ok=true
      break
    fi
    echo -e "${YELLOW}croc send attempt $attempt failed, retrying in 5s...${NC}"
    sleep 5
  done
  if ! $send_ok; then
    echo -e "${RED}Error: croc send failed after 12 attempts${NC}" >&2
    return 1
  fi

  echo -e "${GREEN}Secrets delivered to controller via croc${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Run: $SCRIPT_NAME check"
}

cmd_destroy() {
  check_token

  if ! find_server; then
    echo "No controller server to destroy."
    return
  fi

  echo -e "${RED}WARNING: This will destroy the controller server $FOUND_NAME ($FOUND_IP)${NC}"
  echo "The data in R2 will remain intact."
  echo ""
  read -r -p "Type 'yes' to confirm: " confirm

  if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    return
  fi

  echo -e "${YELLOW}Destroying controller server $FOUND_NAME...${NC}"
  hcloud server delete "$FOUND_NAME"
  echo -e "${GREEN}Destroyed controller server $FOUND_NAME${NC}"
  echo "Persistent volume $VOLUME_NAME was retained (data preserved)."
}

cmd_check() {
  check_token

  if ! find_server; then
    echo -e "${RED}No controller server found${NC}"
    return 1
  fi

  echo -e "${YELLOW}Checking controller server $FOUND_NAME...${NC}"
  echo -e "IP: ${GREEN}${FOUND_IP}${NC}"
  echo "Status: $FOUND_STATUS"

  if [[ "$FOUND_STATUS" != "running" ]]; then
    echo -e "${RED}Server is not running${NC}"
    return 1
  fi

  # Set up host key verification for this IP
  setup_host_verification "$FOUND_IP"

  # Check SSH connectivity with verbose debug on failure
  echo -n "SSH connectivity: "
  local ssh_err ssh_exit
  ssh_err=$(mktemp)
  ssh -o ConnectTimeout=10 -o BatchMode=yes "${SSH_OPTS[@]}" "root@$FOUND_IP" "true" 2>"$ssh_err" && ssh_exit=0 || ssh_exit=$?
  if [[ "$ssh_exit" -eq 0 ]]; then
    echo -e "${GREEN}OK${NC}"
    rm -f "$ssh_err"
  else
    echo -e "${RED}FAILED${NC}"
    echo ""
    echo -e "  ${RED}--- SSH debug ---${NC}"
    echo -e "  Exit code: $ssh_exit"
    echo -e "  Target:    root@${FOUND_IP}:3099"
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
    if timeout 3 bash -c "echo >/dev/tcp/$FOUND_IP/3099" 2>/dev/null; then
      echo -e "${GREEN}reachable${NC} (SSH handshake or auth failed)"
    else
      echo -e "${RED}NOT reachable${NC} (firewall, sshd not running, or cloud-init still in progress)"
    fi

    # Retry with -vvv to capture full debug trace
    echo ""
    echo -e "  ${YELLOW}--- Verbose SSH trace ---${NC}"
    (ssh -vvv -o ConnectTimeout=10 -o BatchMode=yes "${SSH_OPTS[@]}" "root@$FOUND_IP" "true" 2>&1 || true) \
      | grep -iE '(debug1:|error|denied|refused|timeout|closed|banner|identity|offering|authentic|host key)' \
      | head -30 \
      | sed 's/^/  /'

    rm -f "$ssh_err"
    return 1
  fi

  # Check services (single SSH call)
  echo -n "Services: "
  local svc_output
  if svc_output=$(ssh -o ConnectTimeout=10 "${SSH_OPTS[@]}" "root@$FOUND_IP" '
    for svc in headscale headscale-init controller-tailscale-join caddy niks3 postgresql controller-dns-update croc; do
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
        ssh -o ConnectTimeout=10 "${SSH_OPTS[@]}" "root@$FOUND_IP" "
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
  diag_output=$(ssh -o ConnectTimeout=10 "${SSH_OPTS[@]}" "root@$FOUND_IP" '
    echo "=== VOLUME ==="
    if mountpoint -q /mnt/data; then
      echo "mounted"
      df -h /mnt/data --output=size,used,avail,pcent | tail -1
    else
      echo "NOT_MOUNTED"
    fi

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
      errs=$(jaq -r '.v1.errors[]' /var/lib/cloud/data/result.json 2>/dev/null)
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

    echo "=== DNS ==="
    public_ip=$(curl -sf --max-time 5 http://169.254.169.254/hetzner/v1/metadata/public-ipv4 2>/dev/null || echo "unknown")
    dns_ip=$(getent ahosts headscale.panfactumcf.com 2>/dev/null | awk "NR==1{print \$1}" || echo "unresolvable")
    echo "public=$public_ip"
    echo "dns=$dns_ip"

    echo "=== HEADSCALE ==="
    hs_code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 https://headscale.panfactumcf.com/health 2>/dev/null || echo "000")
    echo "$hs_code"

    echo "=== HEADSCALE_USERS ==="
    headscale users list -o json 2>/dev/null | jaq -r '.[].name' 2>/dev/null || echo "error"

    echo "=== HEADSCALE_NODE_NAMES ==="
    headscale nodes list -o json 2>/dev/null | jaq -r ".[].given_name" 2>/dev/null || echo "error"

    echo "=== HEADSCALE_NODE_ONLINE ==="
    headscale nodes list -o json 2>/dev/null | jaq -r ".[].online" 2>/dev/null || echo "error"

    echo "=== PORTS ==="
    ss -tlnp "sport = :5751 or sport = :5432 or sport = :8080 or sport = :50443 or sport = :80 or sport = :443 or sport = :19009" 2>/dev/null || echo "ss not available"

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

    echo "=== LUKS ==="
    VOLUME_DEV=$(echo /dev/disk/by-id/scsi-0HC_Volume_*)
    if [ -b "$VOLUME_DEV" ]; then
      if cryptsetup isLuks "$VOLUME_DEV" 2>/dev/null; then
        echo "luks_format=yes"
      else
        echo "luks_format=no"
      fi
      if [ -b /dev/mapper/controller-data ]; then
        echo "mapper=active"
      else
        echo "mapper=inactive"
      fi
      mount_src=$(findmnt -n -o SOURCE /mnt/data 2>/dev/null || echo "none")
      echo "mount_source=$mount_src"
    else
      echo "no_volume"
    fi

    echo "=== END ==="
  ' 2>/dev/null)

  if [[ -z "$diag_output" ]]; then
    echo -e "${RED}Failed to gather diagnostics via SSH${NC}"
    return 1
  fi

  # Parse and display diagnostics
  local has_errors=false

  # Volume
  echo -n "Volume: "
  local vol_section vol_status
  vol_section=$(echo "$diag_output" | sed -n '/=== VOLUME ===/,/=== /{/===/d;p}')
  vol_status=$(echo "$vol_section" | head -1 | tr -d '[:space:]')
  if [[ "$vol_status" == "mounted" ]]; then
    local vol_disk
    vol_disk=$(echo "$vol_section" | tail -1)
    local v_size _v_used v_avail v_pct
    read -r v_size _v_used v_avail v_pct <<< "$vol_disk"
    echo -e "${GREEN}mounted${NC} (${v_avail} available / ${v_size} total, ${v_pct} used)"
  else
    echo -e "${RED}NOT MOUNTED${NC}"
    has_errors=true
  fi

  # LUKS
  echo -n "Encryption: "
  local luks_section luks_format luks_mapper luks_mount
  luks_section=$(echo "$diag_output" | sed -n '/=== LUKS ===/,/=== /{/===/d;p}')
  if echo "$luks_section" | grep -q "no_volume"; then
    echo -e "${RED}NO VOLUME DEVICE${NC}"
    has_errors=true
  else
    luks_format=$(echo "$luks_section" | sed -n 's/^luks_format=//p' | tr -d '[:space:]')
    luks_mapper=$(echo "$luks_section" | sed -n 's/^mapper=//p' | tr -d '[:space:]')
    luks_mount=$(echo "$luks_section" | sed -n 's/^mount_source=//p' | tr -d '[:space:]')
    if [[ "$luks_format" == "yes" ]] && [[ "$luks_mapper" == "active" ]] && [[ "$luks_mount" == "/dev/mapper/controller-data" ]]; then
      echo -e "${GREEN}OK${NC} (LUKS volume → /dev/mapper/controller-data → /mnt/data)"
    elif [[ "$luks_format" != "yes" ]]; then
      echo -e "${RED}VOLUME NOT ENCRYPTED${NC} (raw volume is not LUKS-formatted)"
      has_errors=true
    elif [[ "$luks_mapper" != "active" ]]; then
      echo -e "${RED}LUKS MAPPER INACTIVE${NC} (volume is LUKS but not unlocked)"
      has_errors=true
    else
      echo -e "${YELLOW}LUKS active but /mnt/data mounted on: ${luks_mount}${NC}"
      has_errors=true
    fi
  fi

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

  # DNS
  echo -n "DNS: "
  local dns_section dns_public dns_resolved
  dns_section=$(echo "$diag_output" | sed -n '/=== DNS ===/,/=== /{/===/d;p}')
  dns_public=$(echo "$dns_section" | head -1 | sed 's/^public=//')
  dns_resolved=$(echo "$dns_section" | tail -1 | sed 's/^dns=//')
  if [[ "$dns_public" == "$dns_resolved" ]]; then
    echo -e "${GREEN}headscale.panfactumcf.com → ${dns_resolved}${NC}"
  else
    echo -e "${RED}MISMATCH${NC} (public=$dns_public, dns=$dns_resolved)"
    has_errors=true
  fi

  # Headscale HTTPS
  echo -n "Headscale: "
  local hs_section hs_code
  hs_section=$(echo "$diag_output" | sed -n '/=== HEADSCALE ===/,/=== /{/===/d;p}')
  hs_code=$(echo "$hs_section" | head -1 | tr -d '[:space:]')
  if [[ "$hs_code" == "200" ]]; then
    echo -e "${GREEN}OK${NC} (HTTPS reachable)"
  else
    echo -e "${RED}HTTP $hs_code${NC}"
    has_errors=true
  fi

  # Headscale default user
  echo -n "Headscale user: "
  local hs_users_section
  hs_users_section=$(echo "$diag_output" | sed -n '/=== HEADSCALE_USERS ===/,/=== /{/===/d;p}')
  if echo "$hs_users_section" | grep -qx "default"; then
    echo -e "${GREEN}OK${NC} (default user exists)"
  elif [[ "$hs_users_section" == "error" ]] || [[ -z "$hs_users_section" ]]; then
    echo -e "${RED}FAILED${NC} (cannot query users)"
    has_errors=true
  else
    echo -e "${RED}FAILED${NC} (default user not found)"
    has_errors=true
  fi

  # Headscale nodes — names and online status are in separate sections (same order)
  echo -n "Headscale node: "
  local hs_node_names hs_node_online
  hs_node_names=$(echo "$diag_output" | sed -n '/=== HEADSCALE_NODE_NAMES ===/,/=== /{/===/d;p}')
  hs_node_online=$(echo "$diag_output" | sed -n '/=== HEADSCALE_NODE_ONLINE ===/,/=== /{/===/d;p}')
  if [[ "$hs_node_names" == "error" ]] || [[ -z "$hs_node_names" ]]; then
    echo -e "${RED}FAILED${NC} (cannot query nodes)"
    has_errors=true
  else
    local ctrl_line
    ctrl_line=$(echo "$hs_node_names" | grep -nx "nix-controller" | head -1 | cut -d: -f1 || true)
    if [[ -n "$ctrl_line" ]]; then
      local ctrl_online
      ctrl_online=$(echo "$hs_node_online" | sed -n "${ctrl_line}p")
      if [[ "$ctrl_online" == "true" ]]; then
        echo -e "${GREEN}OK${NC} (nix-controller online)"
      else
        echo -e "${YELLOW}nix-controller registered but offline${NC}"
      fi
    else
      echo -e "${RED}FAILED${NC} (nix-controller not registered)"
      has_errors=true
    fi
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

  echo -e "${GREEN}Controller server $FOUND_NAME is healthy${NC}"
}

QUEUE_DIR="/var/lib/cache-upload-queue"

cmd_cache() {
  local subcmd="${1:-}"
  case "$subcmd" in
    enqueue)
      shift
      cmd_cache_enqueue "$@"
      ;;
    build-closure)
      shift
      cmd_cache_build_closure "$@"
      ;;
    *)
      cat <<EOF
Usage: $SCRIPT_NAME cache <subcommand>

Subcommands:
  enqueue all [STORE_PATH]        Enqueue all paths in a store closure for upload
                                  (defaults to /run/current-system)
  build-closure [PATH]              List the full build closure (runtime + build-time
                                  deps) by walking the Nix DB deriver chain
                                  (defaults to /run/current-system)

Examples:
  $SCRIPT_NAME cache enqueue all
  $SCRIPT_NAME cache enqueue all /nix/store/...
  $SCRIPT_NAME cache build-closure
  $SCRIPT_NAME cache build-closure /nix/store/...
EOF
      exit 1
      ;;
  esac
}

NIX_DB="/nix/var/nix/db/db.sqlite"

# Print the full build closure of a store path: runtime deps + build-time deps
# (compilers, build tools, sources) discovered by walking the deriver chain in
# the Nix SQLite database.  CA derivations don't preserve build-dep edges in
# .drv files, so normal nix-store queries only return the runtime closure.
# This recursive CTE follows ValidPaths.deriver → Refs up to --depth levels.
cmd_cache_build_closure() {
  local store_path="/run/current-system"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -*) echo -e "${RED}Unknown option: $1${NC}" >&2; exit 1 ;;
      *) store_path="$1" ;;
    esac
    shift
  done

  if [[ ! -e "$store_path" ]]; then
    echo -e "${RED}Error: $store_path does not exist${NC}" >&2
    exit 1
  fi

  if [[ ! -f "$NIX_DB" ]]; then
    echo -e "${RED}Error: Nix database not found at $NIX_DB${NC}" >&2
    exit 1
  fi

  local drv
  drv=$(nix-store -qd "$store_path" 2>/dev/null || true)
  if [[ -z "$drv" || "$drv" == "unknown-deriver" || ! -e "$drv" ]]; then
    echo -e "${YELLOW}Warning: cannot determine deriver, falling back to runtime closure${NC}" >&2
    nix-store -qR "$store_path"
    return
  fi

  local paths
  paths=$(sqlite3 "$NIX_DB" "
    WITH RECURSIVE build_closure(path_id) AS (
      SELECT id FROM ValidPaths WHERE deriver = '$drv'
      UNION
      SELECT ref.reference
      FROM Refs ref
      JOIN build_closure bc ON ref.referrer = bc.path_id
      UNION
      SELECT ref.reference
      FROM build_closure bc
      JOIN ValidPaths vp ON bc.path_id = vp.id
      JOIN ValidPaths vp_drv ON vp.deriver = vp_drv.path
      JOIN Refs ref ON ref.referrer = vp_drv.id
    )
    SELECT DISTINCT vp.path
    FROM build_closure bc
    JOIN ValidPaths vp ON bc.path_id = vp.id
    WHERE vp.path NOT LIKE '%.drv';
  ")

  local total runtime_count build_only_count
  total=$(echo "$paths" | wc -l)
  runtime_count=$(nix-store -qR "$store_path" | wc -l)
  build_only_count=$((total - runtime_count))

  echo "$paths"
  echo -e "${GREEN}Total: $total paths (runtime: $runtime_count, build-time: $build_only_count)${NC}" >&2
}

cmd_cache_enqueue() {
  local subcmd="${1:-}"
  if [[ "$subcmd" != "all" ]]; then
    echo "Usage: $SCRIPT_NAME cache enqueue all [STORE_PATH]"
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

cmd_ssh() {
  local no_verify=false
  local -a remote_cmd=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-verify) no_verify=true ;;
      --)     shift; remote_cmd=("$@"); break ;;
      *)      echo -e "${RED}Unknown option: $1${NC}" >&2; exit 1 ;;
    esac
    shift
  done

  check_token

  if ! find_server; then
    echo -e "${RED}No controller server found${NC}" >&2
    exit 1
  fi

  if [[ "$no_verify" == "true" ]]; then
    SSH_OPTS=("${SSH_BASE_OPTS[@]}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
  else
    setup_host_verification "$FOUND_IP"
  fi

  if [[ ${#remote_cmd[@]} -gt 0 ]]; then
    exec ssh "${SSH_OPTS[@]}" "root@$FOUND_IP" "${remote_cmd[@]}"
  else
    exec ssh "${SSH_OPTS[@]}" "root@$FOUND_IP"
  fi
}

cmd_cleanup() {
  check_token

  local snapshots
  snapshots=$(hcloud image list -t snapshot -l type=controller -o json 2>/dev/null)

  local count
  count=$(echo "$snapshots" | jaq 'if . == null then 0 else length end')

  if [[ "$count" -le 1 ]]; then
    echo "Nothing to clean up ($count snapshot)."
    return
  fi

  # Sort by creation date, drop the latest, delete the rest
  local old_ids
  old_ids=$(echo "$snapshots" | jaq -r 'sort_by(.created) | .[:-1] | .[].id')

  local deleted=0
  for id in $old_ids; do
    local desc
    desc=$(echo "$snapshots" | jaq -r ".[] | select(.id == $id) | .description // .created")
    echo -e "${YELLOW}Deleting snapshot $id ($desc)...${NC}"
    hcloud image delete "$id"
    deleted=$((deleted + 1))
  done

  echo -e "${GREEN}Deleted $deleted old snapshot(s), kept latest${NC}"
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
  ssh)
    shift
    cmd_ssh "$@"
    ;;
  check)
    cmd_check
    ;;
  cache)
    shift
    cmd_cache "$@"
    ;;
  cleanup)
    cmd_cleanup
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
