# CreateSecret Workflow

Create or update an age-encrypted secret in `secrets/` using the `create-secret` devshell script, then wire it into the NixOS module that consumes it.

## Prerequisites

- You MUST be inside the `nix develop` devshell (the `create-secret` command is only available there)
- The user has told you the secret name and either provided the value or told you how to obtain it

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Determine the Secret Name and Value

Identify the secret name and value source from the user's request:

| Situation | Action |
|-----------|--------|
| User provides the value directly | Write to a temp file, use `--file`, then delete the temp file. **Never use `--value` or stdin piping with literal values** — both leak the secret into process args or shell history |
| User says to read from a file | Use `--file <path>` flag |
| Value is in a KeePassXC entry | Use the KeePassXC skill to retrieve it, write to a temp file, use `--file`, then delete |
| Value should be randomly generated | Generate directly into a temp file (e.g., `openssl rand -base64 32 > "$tmp"`), use `--file`, then delete |
| User wants to enter it manually | Do NOT use `--value` (interactive prompt will activate) — inform the user they'll be prompted |

The secret name should be lowercase with hyphens, matching the convention of existing secrets (e.g., `github-token`, `hetzner-api-token`, `cache-signing-key`).

### 2. Check for Existing Secret

Run:

```bash
ls secrets/<name>.age 2>/dev/null
```

| Result | Action |
|--------|--------|
| File exists and user wants to update | Add `--force` flag |
| File exists and user didn't mention updating | Ask the user if they want to overwrite |
| File does not exist | Proceed normally |

### 3. Create the Encrypted Secret

Run the `create-secret` command. **Always use `--file`** to avoid leaking secret values into process argument lists or shell history.

**Standard (preferred):**

```bash
tmp=$(mktemp) && trap "rm -f '$tmp'" EXIT
# write the secret value to the temp file (method depends on source)
create-secret <name> --file "$tmp"
```

**From an existing file:**

```bash
create-secret <name> --file /path/to/value
```

**Multiple secrets in batch** (use `--no-rekey` on all but the last):

```bash
create-secret secret-one --file /tmp/value1 --no-rekey
create-secret secret-two --file /tmp/value2
```

**Interactive** (user enters value at a masked prompt — no file needed):

```bash
create-secret <name>
```

The script will:
1. Encrypt the value with all YubiKey recipients from `yubikeys/*.pub`
2. Write to `secrets/<name>.age`
3. Run `agenix rekey` to rekey for all machines (unless `--no-rekey`)

### 4. Add the Module Reference

If this is a new secret (not updating an existing one), it MUST be referenced in a NixOS module so it gets decrypted at activation time.

Find or create the module that will consume this secret and add:

```nix
age.secrets.<name> = {
  rekeyFile = ../../../secrets/<name>.age;
};
```

The `rekeyFile` path is relative to the module file — adjust `../` depth to reach the repo root's `secrets/` directory.

**Common additional options:**

```nix
age.secrets.<name> = {
  rekeyFile = ../../../secrets/<name>.age;
  # Optional overrides (defaults are usually fine):
  # owner = "root";          # default
  # group = "root";          # default
  # mode = "0400";           # default
  # path = "/run/agenix/<name>";  # default, override for specific paths
  # symlink = true;          # default, set false for files that can't be symlinks
};
```

The decrypted secret is available at runtime via:

```nix
config.age.secrets.<name>.path   # → /run/agenix/<name>
```

### 5. Stage the Files

Run:

```bash
git add secrets/<name>.age secrets/rekeyed/
```

If a module was created or modified, stage that too:

```bash
git add modules/path/to/module.nix
```

### 6. Report Results

Tell the user:
1. The secret was created at `secrets/<name>.age`
2. Which module references it (and the runtime path)
3. The files that were staged
4. Remind them to deploy (`nixos-rebuild switch`) to make the secret available on the target machine

## Guidelines

- **Never log secret values** — do not echo, print, or include secret values in any output or commit messages
- **Always use `--file`** — never use `--value` or pipe literal secrets via stdin, as both expose the value in process argument lists. Write to a temp file first, pass `--file`, then delete the temp file
- **Always rekey** after creating secrets unless batching multiple secrets (use `--no-rekey` for all but the last)
- **Use the naming convention** — lowercase with hyphens: `my-service-token`, not `myServiceToken` or `MY_SERVICE_TOKEN`
- **The `rekeyFile` path matters** — it must be relative to the module file that declares it, with enough `../` to reach the repo root
- **Secrets are per-repo, not per-machine** — the master `.age` file is shared; `agenix rekey` creates per-host copies. Per-machine secrets (host keys, syncthing) use the `secrets/machines/<host>/` pattern instead and have their own dedicated scripts
