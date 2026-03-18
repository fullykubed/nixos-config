# Installing a New Machine

Step-by-step guide for adding a new machine and installing NixOS using the custom installer ISO. See [architecture](architecture.md) for how the pieces fit together and [troubleshooting](troubleshooting.md) for common issues.

## Prerequisites

- An existing machine with this repository checked out (in the `nix develop` shell)
- A USB drive (16+ GB recommended)
- A YubiKey (for secret encryption and host key decryption)

## Part 1: Prepare the Configuration (Existing Machine)

### 1. Create the machine file

Copy an existing machine config as a starting point:

```bash
# For a desktop
cp machines/tower.nix machines/<machine-name>.nix

# For a laptop
cp machines/starfighter.nix machines/<machine-name>.nix
```

Edit `machines/<machine-name>.nix` and adjust:

| Section | What to change |
|---------|---------------|
| `imports` | Pick the right CPU/GPU modules from `modules/utility/` (e.g. `intel-cpu.nix`, `amd-cpu.nix`, `amd-gpu.nix`, `laptop.nix`) |
| `networking.hostName` | Set to `fullykubed-<machine-name>` |
| `networking.hostId` | Generate with `head -c4 /dev/urandom \| od -A n -t x4 \| tr -d ' \n'` |
| `cpuVendor` | `"intel"` or `"amd"` |
| `cpuCount` | Number of CPU threads (`nproc` on similar hardware, or check specs) |
| `monitors` | Use best-guess values; verify after first boot with `swaymsg -t get_outputs` |
| `disko.devices` | Adjust partition sizes if needed (swap, EFI). The ZFS pool name must match `boot.zfs.requestEncryptionCredentials` |

For laptops, omit `powerManagement.cpuFreqGovernor` — the `laptop.nix` module uses auto-cpufreq instead.

The machine is automatically registered in `flake.nix` — any `.nix` file in `machines/` becomes a `fullykubed-<name>` nixosConfiguration.

### 2. Generate a host key

```bash
generate-host-key fullykubed-<machine-name>
```

This generates the key, encrypts it with YubiKey recipients, and automatically runs `agenix rekey` to re-encrypt all secrets for the new host. If keys already exist it will prompt before overwriting. You can also run `generate-host-key` with no arguments for an interactive machine picker.

### 3. Generate a Syncthing key

```bash
generate-syncthing-key fullykubed-<machine-name>
```

This generates a Syncthing key/certificate pair, encrypts both with YubiKey recipients, stores the encrypted files in `secrets/machines/fullykubed-<machine-name>/`, writes the plaintext device ID, and runs `agenix rekey`.

After running the script, add the device to `nixosDevices` in `modules/utility/syncthing.nix` with its folder memberships:

```nix
"fullykubed-<machine-name>" = {
  id = readDeviceId ../../secrets/machines/fullykubed-<machine-name>/syncthing-device-id;
  folders = [ "keepass" ];
};
```

Then commit:

```bash
git add secrets/machines/fullykubed-<machine-name>/ secrets/rekeyed/ modules/utility/syncthing.nix
git commit -m "feat(<machine-name>): add Syncthing identity"
```

See [Syncthing docs](../syncthing.md) for full details on folder and device management.

### 4. Build and flash the installer USB

```bash
flash-installer 
```

Write down the **installer passphrase** displayed at the end.

**Important:** The USB contains a hardcoded timestamp used to set the hardware clock during installation. Boot the USB and run `install-machine` within **30 minutes** of flashing. If more time has passed, re-run `flash-installer` to get a fresh timestamp.


## Part 2: Install NixOS (New Machine)

### 5. Boot the installer USB

Boot from the USB drive. Make sure Secure Boot is **disabled** for the initial install.

### 6. Run the installer

```bash
sudo install-machine
```

You will be prompted for three things:

1. **ZFS encryption passphrase** — choose a strong one, required on every boot
2. **Installer passphrase** — from step 4
3. **Root password**

### 7. Reboot

Remove the USB drive and boot from the internal drive. Enter the ZFS passphrase when prompted.

## Part 3: Post-Install Setup (New Machine)

### 8. Verify hardware values

```bash
swaymsg -t get_outputs   # monitor output names and resolutions
```

Update the `monitors` section in `machines/<machine-name>.nix` with the correct output names, resolutions, and positions. The installer warns if `cpuCount` doesn't match the actual hardware.

### 9. Set up Secure Boot

Reboot into BIOS, enable Setup Mode under Security settings, then boot back into NixOS. Keys are enrolled automatically by a systemd service.

```bash
sudo sbctl status   # verify
```

Enable Secure Boot in the BIOS.

### 10. Rebuild

```bash
cd /etc/nixos
./modules/common/scripts/scripts/un.sh
```

### 11. Verify

```bash
zpool status            # ZFS pool healthy
diff -r /boot1 /boot2   # boot partitions synced
sudo sbctl status        # Secure Boot active
ls /run/agenix/          # secrets decrypted
systemctl --failed       # no failed services
```

## Quick Reference

| Step | Where | What |
|------|-------|------|
| 1-4 | Existing machine | Create machine config, generate host key, generate Syncthing key, flash USB |
| 5-7 | New machine (installer USB) | Boot, run `install-machine`, reboot |
| 8-11 | New machine (installed) | Verify monitors, Secure Boot, rebuild, verify |
