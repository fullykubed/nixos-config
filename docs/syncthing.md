# Syncthing

Declarative Syncthing configuration with pre-generated device identities. Every NixOS machine ships with Syncthing ready to connect — no manual device ID exchange or post-install setup.

## How it works

Syncthing authenticates peers using TLS certificates. The **device ID** is the SHA-256 fingerprint of a device's certificate. If two devices have each other's device IDs in their config, they trust each other automatically on connection.

This config pre-generates each machine's TLS key/cert pair, encrypts them with agenix, and stores the device IDs in plaintext. At activation, agenix decrypts the key/cert and Syncthing starts with the correct identity and a full peer list.

## Module structure

```
modules/utility/syncthing.nix          # Core logic (standalone, no desktop assumptions)
modules/common/syncthing/default.nix   # Thin wrapper for desktop machines
```

The **utility module** contains:
- `folderRegistry` — all available folders (name, ID, path template, sync type)
- `nixosDevices` — all NixOS machines with device IDs and folder memberships
- `externalDevices` — non-NixOS devices (phones, Macs) with device IDs and folder memberships
- Config assembly that excludes the current host from its peer list and builds folder configs

The **common wrapper** imports the utility module and:
- Sets `syncthing.user`/`group`/`dataDir` from `config.username`/`config.homeDir`
- Declares agenix secrets for the host's key and cert
- Passes decrypted secret paths to `services.syncthing.key`/`.cert`

Server images can import the utility module directly without the common wrapper.

## Secret file layout

```
secrets/machines/<hostname>/
├── syncthing-key.age      # Private TLS key (YubiKey-encrypted)
├── syncthing-cert.age     # TLS certificate (YubiKey-encrypted)
└── syncthing-device-id    # Plaintext device ID (derived from cert)
```

The device ID is not secret — it identifies the node in the cluster and is read by the module at build time via `builtins.readFile`.

## Generating keys for a new machine

```bash
generate-syncthing-key [hostname]
```

Without arguments, presents an interactive machine selection menu. The script:

1. Runs `syncthing generate` to produce `key.pem`, `cert.pem`, and `config.xml`
2. Encrypts key and cert with `rage` using YubiKey recipients from `yubikeys/*.pub`
3. Extracts the device ID from `config.xml`
4. Stages the files with `git add` and runs `agenix rekey`

After the script completes:

```bash
git add secrets/rekeyed/
git commit -m "feat(syncthing): add keys for <hostname>"
```

## Importing keys from a running machine

To preserve an existing Syncthing identity:

1. Copy the key and cert:

```bash
scp <hostname>:~/.config/syncthing/key.pem /tmp/key.pem
scp <hostname>:~/.config/syncthing/cert.pem /tmp/cert.pem
```

2. Encrypt with YubiKey recipients:

```bash
RECIPIENTS=()
for pubkey in yubikeys/*.pub; do
  recipient=$(grep -oP 'age1\S+' "$pubkey")
  RECIPIENTS+=(-r "$recipient")
done

rage -e "${RECIPIENTS[@]}" -o secrets/machines/<hostname>/syncthing-key.age /tmp/key.pem
rage -e "${RECIPIENTS[@]}" -o secrets/machines/<hostname>/syncthing-cert.age /tmp/cert.pem
```

3. Record the device ID:

```bash
ssh <hostname> syncthing cli show system | jq -r .myID > secrets/machines/<hostname>/syncthing-device-id
```

4. Rekey and commit:

```bash
agenix rekey
git add secrets/machines/<hostname>/ secrets/rekeyed/
```

## Adding a new NixOS device

1. Generate or import keys (see above)
2. Add the device to `nixosDevices` in `modules/utility/syncthing.nix`:

```nix
"fullykubed-newhost" = {
  id = readDeviceId ../../secrets/machines/fullykubed-newhost/syncthing-device-id;
  folders = [ "keepass" ];
};
```

3. Rebuild all machines so they learn the new peer

## Adding a new external device

Add the device to `externalDevices` in `modules/utility/syncthing.nix`:

```nix
"my-phone" = {
  id = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
  folders = [ "keepass" ];
};
```

The external device will need to accept your NixOS machines as peers on its side.

## Adding a new folder

1. Add the folder to `folderRegistry` in `modules/utility/syncthing.nix`:

```nix
documents = {
  id = "documents";
  label = "Documents";
  pathTemplate = "${cfg.dataDir}/documents";
};
```

2. Add the folder name to the `folders` list of each device that should sync it (in `nixosDevices` and/or `externalDevices`)
