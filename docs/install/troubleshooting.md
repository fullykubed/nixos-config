# Installer Troubleshooting

Common issues during and after installation.

## During Installation

### Disko fails

```bash
# Export any existing ZFS pools
zpool export -a
# Wipe the disk and retry
sudo sgdisk --zap-all /dev/nvme0n1
```

### HOSTKEY partition not found

The installer looks for a partition labeled `HOSTKEY` via `blkid`. This means the USB was not prepared with `flash-installer`, or the partition was already wiped.

Re-flash the USB with `flash-installer` and try again.

### Installer passphrase rejected

The passphrase is case-sensitive and base64-encoded (includes uppercase, lowercase, digits, `+`, `/`). Copy it exactly as displayed by `flash-installer`.

### nixos-install fails

Make sure the flake target name matches `networking.hostName` in the machine file. The expected format is `fullykubed-<machine-name>`.

### install-date not found warning

The installer prints a warning if the `install-date` file is missing from the HOSTKEY partition. This means the USB was flashed with an older version of `flash-installer` that didn't write the timestamp. Re-flash the USB to get a fresh timestamp, or set the clock manually before rebooting:

```bash
date -us "2026-03-17 12:00:00"   # approximate UTC time
hwclock --systohc --utc
```

## After First Boot

### ZFS pool won't import on boot

```bash
zpool import -f rpool   # or your pool name
zfs load-key rpool
zfs mount -a
```

### Chrony fails to sync (NTS certificate errors)

Chrony uses NTS-only servers with `authselectmode require`. If the hardware clock is too far off, TLS certificate validation fails and chrony cannot sync. Check the system time:

```bash
date
chronyc -n sources    # should show reachable sources
journalctl -u chronyd # look for NTS-KE or certificate errors
```

If the clock is wrong, set it manually and restart chrony:

```bash
sudo date -us "2026-03-17 12:00:00"   # approximate UTC time
sudo hwclock --systohc --utc
sudo systemctl restart chronyd
```

This usually means the USB was flashed too long before running the installer, or the `install-date` file was missing. For future installs, run `install-machine` within 30 minutes of flashing.

### Secrets not decrypted

Check that the SSH host key is in place and matches what agenix-rekey encrypted against:

```bash
# Verify host key exists
ls -la /etc/ssh/ssh_host_ed25519_key

# Compare fingerprint with repo
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
ssh-keygen -lf secrets/machines/fullykubed-<machine-name>/ssh-host-key.pub
```

If they don't match, the host key on the target doesn't match the one used for rekeying. Re-flash the USB and reinstall.

### Network interface name changed

```bash
ip link show   # find the new name
# Update machines/<machine-name>.nix, then rebuild
./modules/common/scripts/scripts/un.sh
```

### Secure Boot keys not enrolled

The `secureboot-enroll` service only runs when the firmware is in Setup Mode. Verify:

```bash
sudo sbctl status
```

If Setup Mode is not active, reboot into BIOS and enable it, then boot back into NixOS.

### Boot partitions out of sync

The `boot-sync` activation script runs `rsync /boot1/ /boot2/` on every activation. If the partitions are out of sync, rebuild:

```bash
./modules/common/scripts/scripts/un.sh
```

Or manually sync:

```bash
sudo rsync -avq --delete /boot1/ /boot2/
```
