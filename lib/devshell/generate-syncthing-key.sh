#!/usr/bin/env bash
# Generate a Syncthing key/cert pair for a machine and encrypt with YubiKey
# recipients via rage. Stores device ID as plaintext for config reference.
# Usage: generate-syncthing-key [hostname]

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
  # Build display labels with syncthing key status
  labels=()
  for m in "${all_names[@]}"; do
    if [[ -f "secrets/machines/${m}/syncthing-key.age" ]]; then
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

# ------------------------------------------------------------------------------
# Check for existing Syncthing keys
# ------------------------------------------------------------------------------

KEY_DIR="secrets/machines/${HOSTNAME}"
if [[ -f "$KEY_DIR/syncthing-key.age" ]]; then
  info "Syncthing key already exists for $HOSTNAME"
  read -rp ":: Overwrite? [y/N] " confirm
  case $confirm in
    y|Y|yes) ;;
    *)       error "aborted" ;;
  esac
fi

# ------------------------------------------------------------------------------
# Generate and encrypt key/cert pair
# ------------------------------------------------------------------------------

# Collect YubiKey recipients
RECIPIENTS=()
for pubkey in yubikeys/*.pub; do
  [[ -f "$pubkey" ]] || error "no YubiKey public keys found in yubikeys/"
  recipient=$(grep -oP 'age1\S+' "$pubkey") || continue
  RECIPIENTS+=(-r "$recipient")
done
[[ ${#RECIPIENTS[@]} -gt 0 ]] || error "no age recipients found in yubikeys/*.pub"

# Generate key/cert in a temp directory
TMP_DIR=$(mktemp -d)
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

info "Generating Syncthing key/cert pair..."
syncthing generate --home="$TMP_DIR"

# Encrypt key and cert with YubiKey recipients
info "Encrypting key/cert with YubiKey recipients..."
mkdir -p "$KEY_DIR"
rage -e "${RECIPIENTS[@]}" -o "$KEY_DIR/syncthing-key.age" "$TMP_DIR/key.pem"
rage -e "${RECIPIENTS[@]}" -o "$KEY_DIR/syncthing-cert.age" "$TMP_DIR/cert.pem"

# ------------------------------------------------------------------------------
# Extract device ID
# ------------------------------------------------------------------------------

DEVICE_ID=$(grep -oP 'device id="\K[^"]+' "$TMP_DIR/config.xml" | head -1)
[[ -n "$DEVICE_ID" ]] || error "failed to extract device ID from config.xml"
echo "$DEVICE_ID" > "$KEY_DIR/syncthing-device-id"

info ""
info "Generated Syncthing identity for $HOSTNAME:"
info "  Device ID: $DEVICE_ID"
info "  $KEY_DIR/syncthing-key.age  (private key, YubiKey-encrypted)"
info "  $KEY_DIR/syncthing-cert.age (certificate, YubiKey-encrypted)"
info "  $KEY_DIR/syncthing-device-id (plaintext device ID)"

info ""
info "Staging secret files..."
git add "$KEY_DIR/syncthing-key.age" "$KEY_DIR/syncthing-cert.age" "$KEY_DIR/syncthing-device-id"

info "Rekeying secrets..."
agenix rekey

info ""
info "Done. Next steps:"
info "  1. Update nixosDevices in modules/utility/syncthing.nix (if new machine)"
info "  2. git add secrets/rekeyed/"
