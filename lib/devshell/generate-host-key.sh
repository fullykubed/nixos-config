#!/usr/bin/env bash
# Generate an SSH host key pair for a machine and encrypt the private key
# with YubiKey recipients via rage. Automatically rekeys all secrets afterward.
# Usage: generate-host-key [hostname]

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || { echo ":: Error: not in a git repository" >&2; exit 1; }
export REPO_ROOT
cd "$REPO_ROOT" || exit

info()  { echo ":: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

# ------------------------------------------------------------------------------
# Select target machine
# ------------------------------------------------------------------------------

MACHINES_JSON=$(list-machines)
[[ -n "$MACHINES_JSON" ]] || error "failed to discover machines"

mapfile -t all_names < <(echo "$MACHINES_JSON" | jq -r '.[].name')
[[ ${#all_names[@]} -gt 0 ]] || error "no machines found in flake"

HOSTNAME="${1:-}"

if [[ -n "$HOSTNAME" ]]; then
  # Validate the provided name
  found=false
  for m in "${all_names[@]}"; do
    [[ "$m" == "$HOSTNAME" ]] && { found=true; break; }
  done
  $found || error "unknown machine '$HOSTNAME'. Available: ${all_names[*]}"
else
  # Build display labels with key status
  labels=()
  for m in "${all_names[@]}"; do
    has_key=$(echo "$MACHINES_JSON" | jq -r --arg name "$m" '.[] | select(.name == $name) | .hasHostKey')
    if [[ "$has_key" == "true" ]]; then
      labels+=("$m [has key]")
    else
      labels+=("$m [no key]")
    fi
  done

  info "Available machines:"
  PS3=$'\n:: Select a machine: '
  select choice in "${labels[@]}"; do
    if [[ -n "$choice" ]]; then
      # Extract machine name (strip the status suffix)
      HOSTNAME="${choice%% \[*}"
      break
    fi
    echo "Invalid selection, try again." >&2
  done
fi

# Check for existing keys
KEY_DIR="secrets/machines/${HOSTNAME}"
if [[ -d "$KEY_DIR" ]]; then
  info "$KEY_DIR already exists."
  read -rp ":: Overwrite existing host key? [y/N] " confirm
  case $confirm in
    y|Y|yes) rm -rf "$KEY_DIR" ;;
    *)       error "aborted" ;;
  esac
fi

# ------------------------------------------------------------------------------
# Generate and encrypt key
# ------------------------------------------------------------------------------

# Collect YubiKey recipients
RECIPIENTS=()
for pubkey in yubikeys/*.pub; do
  [[ -f "$pubkey" ]] || error "no YubiKey public keys found in yubikeys/"
  recipient=$(grep -oP 'age1\S+' "$pubkey") || continue
  RECIPIENTS+=(-r "$recipient")
done
[[ ${#RECIPIENTS[@]} -gt 0 ]] || error "no age recipients found in yubikeys/*.pub"

# Generate key pair in a temp directory
TMP_DIR=$(mktemp -d)
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

ssh-keygen -t ed25519 -f "$TMP_DIR/ssh-host-key" -N "" -q -C "root@${HOSTNAME}"

# Encrypt private key with YubiKey recipients
info "Encrypting private key with YubiKey recipients..."
rage -e "${RECIPIENTS[@]}" -o "$TMP_DIR/ssh-host-key.age" "$TMP_DIR/ssh-host-key"

# Write to repo
mkdir -p "$KEY_DIR"
cp "$TMP_DIR/ssh-host-key.age" "$KEY_DIR/ssh-host-key.age"
cp "$TMP_DIR/ssh-host-key.pub" "$KEY_DIR/ssh-host-key.pub"

info "Generated host key for $HOSTNAME:"
info "  $KEY_DIR/ssh-host-key.age (private, YubiKey-encrypted)"
info "  $KEY_DIR/ssh-host-key.pub (public)"

# ------------------------------------------------------------------------------
# Rekey secrets
# ------------------------------------------------------------------------------

info ""
info "Rekeying secrets for new host key..."
agenix rekey

info ""
info "Done. Next step:"
info "  git add $KEY_DIR/ secrets/rekeyed/"
