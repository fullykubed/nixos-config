#!/usr/bin/env bash
set -euo pipefail

# Values substituted at build time by lib/installer/default.nix
MACHINE="@machine@"
TOPLEVEL="@toplevel@"
DISKO_SCRIPT="@diskoScript@"
TARGET_DISKS=(@targetDisks@)
CPU_COUNT="@cpuCount@"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}==>${NC} ${BOLD}$*${NC}"; }
error() { echo -e "${RED}ERROR:${NC} $*" >&2; exit 1; }

# Ensure running as root
[[ $EUID -eq 0 ]] || error "This script must be run as root (use sudo)"

info "Installing: $MACHINE"
echo
info "Target disk(s):"
for disk in "${TARGET_DISKS[@]}"; do
  echo
  if [[ -b "$disk" ]]; then
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$disk"
  else
    echo "  $disk (not found — will be created by disko if available)"
  fi
done
echo
echo -e "${RED}${BOLD}WARNING: This will ERASE the above disk(s) and install NixOS.${NC}"
read -rp "Type 'yes' to continue: " confirm
[[ "$confirm" == "yes" ]] || { echo "Aborted."; exit 1; }

# Export any existing ZFS pools to avoid conflicts
info "Exporting any existing ZFS pools..."
zpool export -a 2>/dev/null || true

# Run disko (partitions, creates encrypted ZFS pool, mounts to /mnt)
info "Running disko (partitioning and formatting)..."
echo "  You will be prompted for a ZFS encryption passphrase."
echo
"$DISKO_SCRIPT"

# Verify mounts
info "Verifying mounts..."
if ! mountpoint -q /mnt; then
  error "/mnt is not mounted. Disko may have failed."
fi
echo "  /mnt is mounted."
echo

# Find and mount the USB key partition to read the encrypted host key
info "Locating encrypted host key on USB..."
KEY_PART=$(blkid -t LABEL=HOSTKEY -o device | head -1)
[[ -b "${KEY_PART:-}" ]] || error "HOSTKEY partition not found — was the USB prepared with flash-installer?"

KEY_MNT=$(mktemp -d)
mount -o ro "$KEY_PART" "$KEY_MNT"
HOST_KEY_ENC="$KEY_MNT/host-key.enc"
[[ -f "$HOST_KEY_ENC" ]] || { umount "$KEY_MNT"; error "Encrypted host key not found on HOSTKEY partition"; }

# Set the system clock from the timestamp baked into the USB by
# flash-installer.  Chrony uses NTS (TLS-based authentication) and
# certificate validation will fail if the clock is too far off, so an
# approximately-correct clock is required before the first boot.
TIMESTAMP_FILE="$KEY_MNT/install-date"
if [[ -f "$TIMESTAMP_FILE" ]]; then
  INSTALL_DATE=$(cat "$TIMESTAMP_FILE")
  info "Setting system clock to $INSTALL_DATE..."
  date -us "$INSTALL_DATE"
  hwclock --systohc --utc
else
  echo -e "${RED}WARNING:${NC} No install-date found on HOSTKEY partition — RTC may be inaccurate"
fi

mkdir -p /mnt/etc/ssh
echo "  Enter the installer passphrase (displayed during flash-installer):"
(umask 077 && openssl enc -d -aes-256-cbc -pbkdf2 -in "$HOST_KEY_ENC" -out /mnt/etc/ssh/ssh_host_ed25519_key)
umount "$KEY_MNT"
rmdir "$KEY_MNT"
ssh-keygen -y -f /mnt/etc/ssh/ssh_host_ed25519_key > /mnt/etc/ssh/ssh_host_ed25519_key.pub
chmod 644 /mnt/etc/ssh/ssh_host_ed25519_key.pub

# Generate RSA host key (some services expect it)
ssh-keygen -t rsa -b 4096 -f /mnt/etc/ssh/ssh_host_rsa_key -N "" -q
chmod 600 /mnt/etc/ssh/ssh_host_rsa_key
chmod 644 /mnt/etc/ssh/ssh_host_rsa_key.pub
echo

# Run nixos-install — secrets decrypt on first boot since the host key
# matches the one agenix-rekey encrypted against.
info "Installing NixOS system (offline, from pre-built closure)..."
nixos-install --system "$TOPLEVEL" --no-channel-copy --no-root-passwd --option substituters "" 
echo

# Set root password
info "Setting root password..."
echo "  You will be prompted to set a root password inside the installed system."
nixos-enter --root /mnt -- passwd root
echo

# Copy the repository source to the target
REPO_SOURCE="/etc/installer/repo"
TARGET_REPO="/mnt/etc/nixos"
info "Copying configuration repository to $TARGET_REPO..."
rm -rf "$TARGET_REPO"
cp -rL --no-preserve=mode "$REPO_SOURCE" "$TARGET_REPO"
echo

# Wipe the HOSTKEY partition to destroy the encrypted host key
if [[ -b "${KEY_PART:-}" ]]; then
  info "Wiping HOSTKEY partition ($KEY_PART)..."
  KEY_SIZE=$(blockdev --getsize64 "$KEY_PART")
  pv -pterab -s "$KEY_SIZE" /dev/zero | dd of="$KEY_PART" bs=4M 2>/dev/null || true
  sync
  info "HOSTKEY partition wiped."
else
  echo -e "${RED}WARNING:${NC} Could not detect HOSTKEY partition — manually wipe it."
fi
echo

DEVICE_NAME="${MACHINE#fullykubed-}"

# Verify cpuCount matches actual hardware
ACTUAL_CPUS=$(nproc)
if [[ "$CPU_COUNT" != "$ACTUAL_CPUS" ]]; then
  echo -e "${RED}WARNING:${NC} cpuCount is set to ${CPU_COUNT} but this machine has ${ACTUAL_CPUS} threads."
  echo "  Update cpuCount in machines/${DEVICE_NAME}.nix and rebuild."
fi

info "Installation complete!"
echo
echo -e "${BOLD}Post-install checklist:${NC}"
echo
echo "  1. Reboot and remove the USB drive"
echo "     Enter ZFS passphrase when prompted at boot"
echo
echo "  2. Verify hardware values in machines/${DEVICE_NAME}.nix:"
echo "     - monitors: swaymsg -t get_outputs (check output names and resolutions)"
echo
echo "  3. Set up Secure Boot:"
echo "     # Reboot into BIOS, enable Setup Mode"
echo "     sudo sbctl enroll-keys"
echo "     # Enable Secure Boot in BIOS"
echo
echo "  4. Rebuild with final config:"
echo "     cd /etc/nixos"
echo "     ./modules/common/scripts/scripts/un.sh"
echo
