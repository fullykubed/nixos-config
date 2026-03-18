#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

info()  { echo ":: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

KEY_DIR="secrets/machines/fullykubed-mini-pc"
SRC_KEY="/home/jack/.config/syncthing/key.pem"
SRC_CERT="/home/jack/.config/syncthing/cert.pem"

[[ -f "$SRC_KEY" ]]  || error "$SRC_KEY not found"
[[ -f "$SRC_CERT" ]] || error "$SRC_CERT not found"

# Collect YubiKey recipients
RECIPIENTS=()
for pubkey in yubikeys/*.pub; do
  [[ -f "$pubkey" ]] || error "no YubiKey public keys found in yubikeys/"
  recipient=$(grep -oP 'age1\S+' "$pubkey") || continue
  RECIPIENTS+=(-r "$recipient")
done
[[ ${#RECIPIENTS[@]} -gt 0 ]] || error "no age recipients found in yubikeys/*.pub"

info "Encrypting $SRC_KEY ..."
rage -e "${RECIPIENTS[@]}" -o "$KEY_DIR/syncthing-key.age" "$SRC_KEY"

info "Encrypting $SRC_CERT ..."
rage -e "${RECIPIENTS[@]}" -o "$KEY_DIR/syncthing-cert.age" "$SRC_CERT"

info ""
info "Done. Imported Syncthing identity for fullykubed-mini-pc."
info "  $KEY_DIR/syncthing-key.age"
info "  $KEY_DIR/syncthing-cert.age"
info "  $KEY_DIR/syncthing-device-id (already set)"
info ""
info "Next: run generate-syncthing-key for tower and starfighter,"
info "then run 'agenix rekey' once all three machines have keys."
