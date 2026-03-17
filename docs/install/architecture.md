# Installer Architecture

How the custom NixOS installer builds, transfers, and bootstraps a new machine.

## Overview

```
 Existing machine                          New machine
 ================                          ===========

 generate-host-key                         boot USB
 (auto-rekeys)                                 |
        |                                      v
        v                                  install-machine
 flash-installer                               |
   |         |                             +---+---+---+---+---+
   v         v                             |   |   |   |   |   |
 build    flash USB                     disko  key nixos root repo
  ISO     + HOSTKEY                            |
   |      partition                         decrypt
   v         |                             host key
 .#installer-iso-*                             |
   |         |                                 v
   +----+----+                          secrets work on
        |                                first boot
        v
   USB drive ready
```

## Components

### generate-host-key

`lib/devshell/generate-host-key.sh` — run once per machine.

1. Uses `list-machines` to discover machines and show an interactive picker (or validates a positional argument)
2. If keys already exist, prompts for confirmation before overwriting
3. Generates an ed25519 SSH key pair in a temp directory
4. Encrypts the private key with all YubiKey recipients via `rage`
5. Writes `secrets/machines/<hostname>/ssh-host-key.{age,pub}`
6. Automatically runs `agenix rekey` to re-encrypt all secrets for the new host key
7. The plaintext private key never touches disk outside the temp directory

The public key is what `agenix-rekey` uses to encrypt secrets for the machine (`modules/common/secrets/default.nix` reads it via `age.rekey.hostPubkey`).

### agenix rekey

Re-encrypts every secret in the repo for the new machine's host public key. Output goes to `secrets/rekeyed/<hostname>/`. On the target machine, agenix decrypts these at activation using the host private key at `/etc/ssh/ssh_host_ed25519_key`. This step runs automatically at the end of `generate-host-key`.

### flash-installer

`lib/devshell/flash-installer.sh` — builds the ISO and prepares the USB drive.

**Phase 1 — Interactive (collects all input upfront):**

1. Selects or validates the target machine name
2. Offers to reuse an existing ISO if one is found
3. Selects and confirms the USB device
4. Decrypts the host key from the repo using YubiKey (`rage`)
5. Re-encrypts it with a random one-time passphrase (`openssl aes-256-cbc`)

**Phase 2 — Unattended:**

1. Builds `nix build .#installer-iso-<machine>` (with optional remote builders)
2. Flashes the ISO to the USB drive via `dd`
3. Appends a 1 MiB FAT32 partition labeled `HOSTKEY` after the ISO data
4. Copies the encrypted host key (`host-key.enc`) to the HOSTKEY partition
5. Writes an `install-date` file containing the current UTC time + 10 minutes (used by `install-machine` to set the hardware clock — see [Clock Bootstrap](#clock-bootstrap))
6. Ejects the drive and displays the installer passphrase

### Installer ISO (lib/installer/default.nix)

A NixOS system built on top of the minimal installation CD. It adds:

- **Pre-built closures** — `isoImage.storeContents` includes the target machine's `system.build.toplevel` and `system.build.diskoScript`, so installation works fully offline
- **Repository snapshot** — the flake source is placed at `/etc/installer/repo` for copying to the target
- **install-machine script** — `lib/installer/install-machine.sh` with build-time substitutions for machine name, toplevel path, disko script path, target disks, and cpuCount

### install-machine

`lib/installer/install-machine.sh` — runs on the new machine after booting the USB.

```
confirm disk wipe
        |
        v
  zpool export -a
        |
        v
  run disko script -----> ZFS passphrase prompt
        |
        v
  verify /mnt mounted
        |
        v
  find HOSTKEY partition (blkid LABEL=HOSTKEY)
        |
        v
  set clock from install-date
        |
        v
  decrypt host key -----> installer passphrase prompt
        |
        v
  place keys in /mnt/etc/ssh/
        |
        v
  nixos-install --system $TOPLEVEL (offline)
        |
        v
  set root password -----> password prompt
        |
        v
  copy repo to /mnt/etc/nixos
        |
        v
  wipe HOSTKEY partition (zero-fill)
        |
        v
  print post-install checklist
```

### Secure Boot enrollment

After first boot, the system handles Secure Boot automatically:

- `modules/common/boot/default.nix` deploys shared PKI keys via agenix (private keys) and activation scripts (public certs) to `/etc/secureboot/`
- Lanzaboote reads keys from `/etc/secureboot/` to sign boot entries
- A `secureboot-enroll` systemd service detects UEFI Setup Mode and runs `sbctl enroll-keys` automatically

No manual key generation is needed — all machines share the same Secure Boot PKI via agenix.

## Clock Bootstrap

Chrony is configured with NTS-only servers and `authselectmode require`. NTS relies on TLS for the key-establishment handshake, so certificate validation must succeed before chrony can obtain any time samples. If the hardware clock is too far off (dead CMOS battery, new hardware, long power-off), TLS validation fails and chrony cannot sync.

To break this chicken-and-egg problem, `flash-installer` writes the current UTC time + 10 minutes to `install-date` on the HOSTKEY partition. `install-machine` reads this file, sets the system clock, and writes it to the RTC with `hwclock --systohc --utc`. This ensures the installed system boots with a close-enough clock for NTS to work.

The 10-minute offset accounts for time between flashing and running the installer. The USB should be used within **30 minutes** of flashing; after that, re-run `flash-installer` to get a fresh timestamp.

## USB Drive Layout

```
+---------------------------+--------------+
| ISO hybrid image          | HOSTKEY      |
| (NixOS installer +        | 1 MiB FAT32  |
|  pre-built closures +     +--------------+
|  repo snapshot)           | host-key.enc |
|                           | install-date |
+---------------------------+--------------+
  Partition 1-2 (ISO)        Partition 3
```

The HOSTKEY partition contains `host-key.enc` (encrypted SSH host key) and `install-date` (UTC timestamp for clock bootstrap). Both are destroyed when `install-machine` zero-wipes the partition after extraction.

## Host Key Lifecycle

```
generate-host-key           flash-installer             install-machine
=================           ===============             ===============

ssh-keygen                  rage decrypt                openssl decrypt
    |                       (YubiKey touch)             (passphrase)
    v                           |                           |
private key (tmp)               v                           v
    |                       plaintext key (tmp)         /mnt/etc/ssh/
    v                           |                       ssh_host_ed25519_key
rage encrypt                    v                           |
(YubiKey recipients)        openssl encrypt                 v
    |                       (random passphrase)         agenix decrypts
    v                           |                       secrets on boot
secrets/machines/               v
  <host>/ssh-host-key.age   HOSTKEY partition
    |                       host-key.enc
    v
agenix rekey (auto) --> secrets/rekeyed/<host>/*.age
```

The plaintext private key exists only momentarily in temp directories during `generate-host-key` and `flash-installer`, and on the HOSTKEY partition (encrypted with a passphrase) until `install-machine` wipes it.

## Key Files

| File | Purpose |
|------|---------|
| `lib/devshell/list-machines.sh` | Outputs JSON of all machines with host key status |
| `lib/devshell/generate-host-key.sh` | Generates and encrypts SSH host key for a machine (auto-rekeys) |
| `lib/devshell/flash-installer.sh` | Builds ISO, decrypts host key, flashes USB |
| `lib/installer/default.nix` | NixOS module for the installer ISO |
| `lib/installer/install-machine.sh` | On-target installation script (template) |
| `modules/common/boot/default.nix` | Secure Boot PKI deployment and auto-enrollment |
| `modules/common/secrets/default.nix` | Per-host agenix-rekey configuration |
| `secrets/machines/<host>/` | Per-machine host key (encrypted + public) |
| `secrets/rekeyed/<host>/` | Per-machine rekeyed secrets |
