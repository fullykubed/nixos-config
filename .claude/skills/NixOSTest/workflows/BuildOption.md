# BuildOption Workflow

Build a specific NixOS configuration option that resolves to a derivation. Useful for testing individual subsystems (kernel, initrd, etc files, systemd units) without building the entire system.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Determine Option Path

The user MUST specify a config option path. If they haven't, ask what they want to test. Common options:

| Shorthand | Full option path |
|-----------|-----------------|
| `kernel` | `config.boot.kernelPackages.kernel` |
| `initrd` | `config.system.build.initialRamdisk` |
| `etc` | `config.system.build.etc` |
| `systemd` | `config.systemd.units` |

### 2. Build or Evaluate the Option

```bash
nt-option <option-path> [hostname]
```

Hostname defaults to the current machine. The script tries `nix build` first; if the option isn't a derivation, it falls back to `nix eval`.

Build output is written to a temp log file whose path is printed to stderr. Record this path for stall detection and error analysis.

### 3. Report Results

- **Build succeeded**: Report success and the store path.
- **Eval returned a value**: Display the value. For complex values, format them readably.
- **Failed**: Report the error and suggest checking the relevant module.

## Guidelines

- The `config.system.build` attribute set contains most buildable system components.
- This workflow is useful for isolating build failures to specific subsystems rather than debugging a full system build.
