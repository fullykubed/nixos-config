#!/usr/bin/env bash
# Build the NixOS installer ISO and flash it to a USB drive.
# Usage: flash-installer [MACHINE] [OPTIONS]
#   MACHINE                  Machine name (e.g. fullykubed-starfighter). Prompted if omitted.
#   --build-only             Build the ISO without flashing.
#   -B, --builders N         Use N regular remote builders (0 to disable all)
#   -P, --big-builders N     Use N big-parallel remote builders
#   -o, --offline            Build without network access
#   -S, --no-substituters    Skip all binary cache lookups

info()  { echo ":: $*" >&2; }
error() { echo ":: Error: $*" >&2; exit 1; }

BUILD_ONLY=false
MACHINE=""
BUILDER_COUNT=""
BIG_BUILDER_COUNT=""
OFFLINE_MODE=false
NO_SUBSTITUTERS=false
REPO_ROOT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --build-only)        BUILD_ONLY=true ;;
    -B|--builders)       shift; BUILDER_COUNT="$1" ;;
    -P|--big-builders)   shift; BIG_BUILDER_COUNT="$1" ;;
    -o|--offline)        OFFLINE_MODE=true ;;
    -S|--no-substituters) NO_SUBSTITUTERS=true ;;
    --_repo-root)        shift; REPO_ROOT="$1" ;;
    -h|--help)
      echo "Usage: flash-installer [MACHINE] [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --build-only             Build the ISO without flashing"
      echo "  -B, --builders N         Use N regular remote builders (0 to disable all)"
      echo "  -P, --big-builders N     Use N big-parallel remote builders"
      echo "  -o, --offline            Build without network access"
      echo "  -S, --no-substituters    Skip all binary cache lookups"
      echo "  -h, --help               Show this help message"
      exit 0
      ;;
    -*)                  error "unknown option: $1. Run 'flash-installer --help' for usage." ;;
    *)                   MACHINE="$1" ;;
  esac
  shift
done

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || error "not in a git repository"
export REPO_ROOT
cd "$REPO_ROOT" || exit

# Elevate to root for flashing (build-only doesn't need root)
if ! $BUILD_ONLY && [[ $EUID -ne 0 ]]; then
  doas_args=(--_repo-root "$REPO_ROOT")
  [[ -n "$MACHINE" ]]        && doas_args+=("$MACHINE")
  [[ -n "$BUILDER_COUNT" ]]  && doas_args+=(--builders "$BUILDER_COUNT")
  [[ -n "$BIG_BUILDER_COUNT" ]] && doas_args+=(--big-builders "$BIG_BUILDER_COUNT")
  $OFFLINE_MODE              && doas_args+=(--offline)
  $NO_SUBSTITUTERS           && doas_args+=(--no-substituters)
  exec doas "$0" "${doas_args[@]}"
fi

# Run nix commands as the original (non-root) user
ORIG_USER="${DOAS_USER:-$USER}"
as_user() { runuser -u "$ORIG_USER" -- "$@"; }

# ==============================================================================
# Phase 1: Collect all interactive input upfront
# ==============================================================================

# --- Select target machine ---

mapfile -t all_machines < <(as_user list-machines | jq -r '.[].name')
[[ ${#all_machines[@]} -gt 0 ]] || error "no machines found in flake"

if [[ -z "$MACHINE" ]]; then
  info "Available machines:"
  PS3=$'\n:: Select a machine to build: '
  select MACHINE in "${all_machines[@]}"; do
    [[ -n "$MACHINE" ]] && break
    echo "Invalid selection, try again." >&2
  done
else
  # Validate the provided name
  found=false
  for m in "${all_machines[@]}"; do
    [[ "$m" == "$MACHINE" ]] && { found=true; break; }
  done
  $found || error "unknown machine '$MACHINE'. Available: ${all_machines[*]}"
fi

info "Target machine: $MACHINE"

SKIP_BUILD=false
shopt -s nullglob
existing_isos=(result/iso/*.iso)
shopt -u nullglob
if [[ ${#existing_isos[@]} -gt 0 ]]; then
  info "Existing ISO found: ${existing_isos[0]} ($(du -h "${existing_isos[0]}" | cut -f1))"
  read -rp ":: Rebuild? [y]es / [s]kip build / [a]bort: " choice
  case $choice in
    y|yes) ;;
    s|skip) SKIP_BUILD=true ;;
    *)      error "aborted" ;;
  esac
fi

HOST_KEY_AGE="secrets/machines/${MACHINE}/ssh-host-key.age"
[[ -f "$HOST_KEY_AGE" ]] || error "host key not found: $HOST_KEY_AGE (run generate-host-key $MACHINE first)"

if ! $BUILD_ONLY; then
  # --- Select and confirm USB device ---

  mapfile -t usb_devices < <(lsblk -dnpo NAME,TRAN | awk '$2 == "usb" {print $1}')
  [[ ${#usb_devices[@]} -gt 0 ]] || error "no USB devices found"

  if [[ ${#usb_devices[@]} -eq 1 ]]; then
    DEVICE_PATH="${usb_devices[0]}"
    info "Found USB device: $(lsblk -dno NAME,SIZE,MODEL "$DEVICE_PATH")"
  else
    info ""
    info "USB devices:"
    lsblk -d -p -o NAME,SIZE,MODEL,TRAN | grep -E 'usb|TRAN' >&2
    info ""
    read -rp ":: Enter target device (e.g. /dev/sda): " DEVICE_PATH
    [[ -z "$DEVICE_PATH" ]] && error "no device specified"
  fi
  [[ -b "$DEVICE_PATH" ]] || error "$DEVICE_PATH is not a block device"

  # Refuse to flash to devices with mounted partitions
  mounted=$(findmnt -rno SOURCE | grep "^${DEVICE_PATH}" || true)
  if [[ -n "$mounted" ]]; then
    error "$DEVICE_PATH has mounted partitions — unmount first"
  fi

  info ""
  info "This will ERASE ALL DATA on $DEVICE_PATH:"
  lsblk "$DEVICE_PATH" >&2
  info ""
  read -rp ":: Type 'yes' to confirm: " CONFIRM
  [[ "$CONFIRM" == "yes" ]] || error "aborted"

  # --- Decrypt host key (requires YubiKey touch) ---

  info "Decrypting host key (YubiKey touch required)..."
  ENC_KEY=$(mktemp)
  cleanup() { rm -f "$ENC_KEY"; }
  trap cleanup EXIT

  DECRYPTED_KEY=$(mktemp)
  rage -d -i yubikeys/yubikey_a_identity.pub "$HOST_KEY_AGE" > "$DECRYPTED_KEY"

  PASSPHRASE=$(openssl rand -base64 6)
  openssl enc -aes-256-cbc -pbkdf2 -pass "pass:${PASSPHRASE}" -in "$DECRYPTED_KEY" -out "$ENC_KEY"
  rm -f "$DECRYPTED_KEY"
fi

info ""
info "All input collected — the rest runs unattended."
info ""

# ==============================================================================
# Phase 2: Unattended build and flash
# ==============================================================================

# --- Build nix flags ---

nix_flags=()

[[ "$OFFLINE_MODE" == true ]] && nix_flags+=(--offline) && info "Building in offline mode"
[[ "$NO_SUBSTITUTERS" == true ]] && nix_flags+=(--option substitute false) && info "Skipping binary cache lookups"

mk_builder() {
  local host=$1 maxjobs=$2 features=$3
  echo "ssh://remotebuild@${host} x86_64-linux /root/.ssh/builder-key ${maxjobs} 1 ${features}"
}

if [[ -n "$BUILDER_COUNT" ]] || [[ -n "$BIG_BUILDER_COUNT" ]]; then
  builder_list=""
  for i in $(seq 1 "${BUILDER_COUNT:-0}"); do
    [[ -n "$builder_list" ]] && builder_list+="; "
    builder_list+=$(mk_builder "builder-$i" 4 "nixos-test,kvm,benchmark")
  done
  for i in $(seq 1 "${BIG_BUILDER_COUNT:-0}"); do
    [[ -n "$builder_list" ]] && builder_list+="; "
    builder_list+=$(mk_builder "big-builder-$i" 1 "nixos-test,big-parallel,kvm,benchmark")
  done

  if [[ -z "$builder_list" ]]; then
    nix_flags+=(--builders "")
    info "Remote builders disabled"
  else
    nix_flags+=(--builders "$builder_list")
    msg=""
    [[ "${BUILDER_COUNT:-0}" -gt 0 ]] && msg="${BUILDER_COUNT} regular"
    if [[ "${BIG_BUILDER_COUNT:-0}" -gt 0 ]]; then
      [[ -n "$msg" ]] && msg+=" + "
      msg+="${BIG_BUILDER_COUNT} big-parallel"
    fi
    info "Using ${msg} builder(s)"
  fi
fi

# --- Build the installer ISO ---

if $SKIP_BUILD; then
  info "Skipping build, using existing ISO."
else
  info "Building installer ISO for $MACHINE..."
  as_user nix build ".#installer-iso-${MACHINE}" "${nix_flags[@]}"
fi

# Find the built ISO
shopt -s nullglob
isos=(result/iso/*.iso)
shopt -u nullglob
[[ ${#isos[@]} -gt 0 ]] || error "no ISO found in result/iso/"
ISO="${isos[0]}"

ISO_SIZE=$(du -h "$ISO" | cut -f1)
info "ISO: $ISO ($ISO_SIZE)"

if $BUILD_ONLY; then
  exit 0
fi

# --- Flash to USB drive ---

info "Flashing $ISO → $DEVICE_PATH"
pv -pterab "$ISO" | dd of="$DEVICE_PATH" bs=4M oflag=sync 2>/dev/null
sync

# --- Create key partition and copy encrypted host key ---

# Get the ISO size in bytes, round up to next MiB boundary for partition alignment
ISO_BYTES=$(stat --format=%s "$ISO")
START_MIB=$(( (ISO_BYTES + 1048575) / 1048576 ))

# Create a small MBR partition after the ISO data
# (ISO hybrid images use MBR, not GPT, so we use sfdisk)
info "Creating key partition on USB..."
echo "${START_MIB}M,1M,L" | sfdisk --append "$DEVICE_PATH"

# Construct partition device path (sda → sda3, nvme0n1 → nvme0n1p3)
if [[ "$DEVICE_PATH" =~ [0-9]$ ]]; then
  KEY_PART="${DEVICE_PATH}p3"
else
  KEY_PART="${DEVICE_PATH}3"
fi

partx --delete "$DEVICE_PATH" 2>/dev/null || true
partx --add --nr 3 "$DEVICE_PATH"
udevadm settle
[[ -b "$KEY_PART" ]] || error "key partition $KEY_PART not found"

mkfs.vfat -n HOSTKEY "$KEY_PART" >/dev/null

KEY_MNT=$(mktemp -d)
mount "$KEY_PART" "$KEY_MNT"
cp "$ENC_KEY" "$KEY_MNT/host-key.enc"
# Write a timestamp 10 minutes in the future so install-machine can set the
# RTC to an approximately-correct time.  Chrony uses NTS (TLS-based auth)
# and certificate validation fails if the clock is too far off.
date -ud "+10 minutes" '+%Y-%m-%d %H:%M:%S' > "$KEY_MNT/install-date"
umount "$KEY_MNT"
rmdir "$KEY_MNT"
rm -f "$ENC_KEY"

info "Ejecting $DEVICE_PATH..."
eject "$DEVICE_PATH"

info ""
info "============================================"
info "  INSTALLER PASSPHRASE (write this down!):"
info "  ${PASSPHRASE}"
info "============================================"
info ""
info "Done — USB drive is ready to boot."
info "Run on target: sudo install-machine"
info ""
info "WARNING: Run the installer within 30 minutes — the USB"
info "contains a hardcoded timestamp for setting the system clock."
