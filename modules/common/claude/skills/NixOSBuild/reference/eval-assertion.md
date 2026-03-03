# Fix Type: EVAL_ASSERTION

Nix evaluation failed because an `assert` expression or NixOS option assertion evaluated to false.

## Error Patterns

- `error: assertion '...' failed`
- `error: assertion 'lib.assertMsg ...' failed at ...`
- `Failed assertions:` followed by a list of messages

## Common Causes

1. **Incompatible option combination** — two mutually exclusive services or features are both enabled
2. **Missing required option** — enabling a service without setting a required companion option
3. **Version constraint not met** — a module asserts a minimum version or compatible platform
4. **Platform mismatch** — package asserts it only works on certain platforms (`meta.platforms`)
5. **Deprecated option** — a module asserts that an old option is no longer valid

## Fix Strategies

### Read the assertion message

The assertion message almost always tells you exactly what's wrong. It typically says:
- Which options conflict
- Which required option is missing
- What value is expected

### Incompatible options

Disable one of the conflicting options, or set the required mediating option.

### Missing required option

Set the required option. Example:
```nix
services.foo.enable = true;
services.foo.domain = "example.com";  # required when foo is enabled
```

### Platform assertion

If a package doesn't support the current platform:
- Check if an alternative package exists
- Check if the assertion is outdated and the package actually works (override `meta.platforms` if so)

### Deprecated option

Migrate to the new option name. The assertion message usually references the replacement.
