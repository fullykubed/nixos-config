# Secret Management

This configuration uses [agenix](https://github.com/ryantm/agenix) with [agenix-rekey](https://github.com/oddlama/agenix-rekey) for managing encrypted secrets. Secrets are encrypted against YubiKey master identities and automatically rekeyed per-host using each machine's SSH host key.

## How it works

1. Secrets are stored age-encrypted in `secrets/`
2. YubiKey public identities in `yubikeys/` serve as master encryption keys
3. `agenix-rekey` re-encrypts each secret for every machine using its SSH host public key (`/etc/ssh/ssh_host_ed25519_key.pub`)
4. Per-host rekeyed secrets are stored in `secrets/rekeyed/<hostname>/`
5. At system activation, secrets are decrypted into `/run/agenix/`

## Adding a new secret

1. Create the encrypted `.age` file in `secrets/`:

```bash
agenix edit secrets/new-secret.age
```

2. Reference it in a module using `rekeyFile`:

```nix
age.secrets.new-secret = {
  rekeyFile = ../../../secrets/new-secret.age;
};
```

The decrypted secret is then available at `config.age.secrets.new-secret.path`.

3. Rekey for all machines:

```bash
agenix rekey
```

## Generating secrets programmatically

Instead of manually creating a secret with `agenix edit`, you can attach a generator to have `agenix generate` create it automatically.

Define the secret with a `generator.script` in your module:

```nix
age.secrets.db-password = {
  rekeyFile = ../../../secrets/db-password.age;
  generator.script = "alnum";  # 48-char alphanumeric password
};
```

Then run:

```bash
agenix generate        # generate all secrets that don't exist yet
agenix generate -f     # regenerate even if the .age file already exists
agenix rekey           # rekey for all machines after generating
```

Built-in generators include `alnum`, `base64`, `hex`, `passphrase`, and `ssh-ed25519`. See the [agenix-rekey docs](https://github.com/oddlama/agenix-rekey) for custom generators.

## Editing secrets non-interactively

`agenix edit` opens `$EDITOR`, which doesn't work for AI agents or scripts. To create or update a secret without an editor, encrypt directly with `age` using the YubiKey recipients from `yubikeys/`:

```bash
echo "my-secret-value" | age -r age1yubikey1q0ztvu6ug0vq4pnawl5w3fqtk6x6un5r6aknrrfqna0th4lpmzntc3qgetc \
                              -r age1yubikey1qw36z5uy055l3n4l9qzy85vxx6cm6m6yyn4pcpgagdd0gmh35ng4gjue23q \
                              -o secrets/new-secret.age
agenix rekey
```

The recipients must match all `masterIdentities` in `modules/common/secrets/default.nix`. To extract them:

```bash
grep -h 'Recipient:' yubikeys/*.pub | grep -o 'age1[^ ]*'
```

## Adding a new master key

1. Generate an age identity from the YubiKey:

```bash
age-plugin-yubikey --generate --slot 1 --name nixos --touch-policy cached --pin-policy always
```

2. Save the public identity to `yubikeys/`:

```bash
age-plugin-yubikey --identity --slot 1 > yubikeys/yubikey_c_identity.pub
```

3. Add the new identity to `modules/common/secrets/default.nix`:

```nix
masterIdentities = [
  ../../../yubikeys/yubikey_a_identity.pub
  ../../../yubikeys/yubikey_b_identity.pub
  ../../../yubikeys/yubikey_c_identity.pub
];
```

4. Re-encrypt all secrets so the new key can decrypt them, then rekey:

```bash
agenix rekey
```

## Directory structure

```
secrets/
├── *.age              # Age-encrypted secret files
├── *.pub              # Corresponding public keys (where applicable)
└── rekeyed/           # Per-machine rekeyed secrets
    ├── jack-desktop/
    ├── jack-mini-pc/
    ├── fullykubed-tower/
    └── fullykubed-mini-pc/

yubikeys/
├── yubikey_a_identity.pub
└── yubikey_b_identity.pub
```

## Configuration

Master identities and rekey settings are defined in `modules/common/secrets/default.nix`.
