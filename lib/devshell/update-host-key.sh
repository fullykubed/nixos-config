#!/usr/bin/env bash
# mnemonic: [u]pdate [h]ost [k]ey
# Decrypts the SSH host key from the repo and installs it on the current
# machine. Requires a YubiKey touch for decryption.
# Usage: update-host-key [-r|--restore]

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo ":: Error: not in a git repository" >&2; exit 1; }
cd "$REPO_ROOT" || exit

info()  { echo ":: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

KEY_PATH="/etc/ssh/ssh_host_ed25519_key"
BACKUP="${KEY_PATH}.bak"

SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME

show_help() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Decrypts the SSH host key from the repo and installs it on the current machine.

Options:
  -r, --restore   Restore the host key from backup (.bak)
  -h, --help      Show this help message
EOF
}

# ------------------------------------------------------------------------------
# Argument parsing
# ------------------------------------------------------------------------------

RESTORE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--restore) RESTORE=true ;;
    -h|--help)    show_help; exit 0 ;;
    *)            error "unknown option: $1" ;;
  esac
  shift
done

# ------------------------------------------------------------------------------
# Restore mode
# ------------------------------------------------------------------------------

if $RESTORE; then
  [[ -f "$BACKUP" ]] || error "no backup found at $BACKUP"
  info "Restoring host key from $BACKUP..."
  if [[ $EUID -ne 0 ]]; then
    doas cp -p "$BACKUP" "$KEY_PATH"
    [[ -f "${BACKUP}.pub" ]] && doas cp -p "${BACKUP}.pub" "${KEY_PATH}.pub"
  else
    cp -p "$BACKUP" "$KEY_PATH"
    [[ -f "${BACKUP}.pub" ]] && cp -p "${BACKUP}.pub" "${KEY_PATH}.pub"
  fi
  info "Done. Host key restored from backup."
  exit 0
fi

# ------------------------------------------------------------------------------
# Detect current machine
# ------------------------------------------------------------------------------

HOSTNAME=$(hostname)
KEY_DIR="secrets/machines/${HOSTNAME}"

[[ -f "$KEY_DIR/ssh-host-key.age" ]] || error "no host key found at $KEY_DIR/ssh-host-key.age"
[[ -f "$KEY_DIR/ssh-host-key.pub" ]] || error "no public key found at $KEY_DIR/ssh-host-key.pub"

info "Machine:    $HOSTNAME"
info "Repo key:   $KEY_DIR/ssh-host-key.age"
info "System key: $KEY_PATH"

# ------------------------------------------------------------------------------
# Decrypt and install
# ------------------------------------------------------------------------------

TMP_DIR=$(mktemp -d)
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# Collect YubiKey identities for decryption
IDENTITIES=()
for pubkey in yubikeys/*.pub; do
  [[ -f "$pubkey" ]] || error "no YubiKey identity files found in yubikeys/"
  IDENTITIES+=(-i "$pubkey")
done

info "Decrypting host key (touch YubiKey when prompted)..."
rage -d "${IDENTITIES[@]}" -o "$TMP_DIR/ssh-host-key" "$KEY_DIR/ssh-host-key.age"

# Compare public keys to check if they differ
if [[ -f "${KEY_PATH}.pub" ]]; then
  existing_pub=$(cat "${KEY_PATH}.pub")
  repo_pub=$(cat "$KEY_DIR/ssh-host-key.pub")
  if [[ "$existing_pub" == "$repo_pub" ]]; then
    info "System key already matches repo. Nothing to do."
    exit 0
  fi
  info "System key differs from repo key."
  read -rp ":: Overwrite existing key? (backup will be saved to ${BACKUP}) [y/N] " confirm
  case $confirm in
    y|Y|yes) ;;
    *)       error "aborted" ;;
  esac

  info "Backing up existing key to $BACKUP..."
  if [[ $EUID -ne 0 ]]; then
    doas cp -p "$KEY_PATH" "$BACKUP"
    doas cp -p "${KEY_PATH}.pub" "${BACKUP}.pub"
  else
    cp -p "$KEY_PATH" "$BACKUP"
    cp -p "${KEY_PATH}.pub" "${BACKUP}.pub"
  fi
fi

info "Installing to $KEY_PATH..."
if [[ $EUID -ne 0 ]]; then
  doas install -m 0600 -o root -g root "$TMP_DIR/ssh-host-key" "$KEY_PATH"
  doas install -m 0644 -o root -g root "$KEY_DIR/ssh-host-key.pub" "${KEY_PATH}.pub"
else
  install -m 0600 -o root -g root "$TMP_DIR/ssh-host-key" "$KEY_PATH"
  install -m 0644 -o root -g root "$KEY_DIR/ssh-host-key.pub" "${KEY_PATH}.pub"
fi

info "Done. Host key updated."
