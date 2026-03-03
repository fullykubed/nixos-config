# Fix Type: Hash Mismatch

Occurs when a fixed-output derivation (source download) produces a different hash than expected.

## Error Signatures

- `hash mismatch in fixed-output derivation`
- `got: sha256-...`
- `specified: sha256-...`

## Common Causes

- Upstream changed the tarball contents without changing the version/URL
- A `fetchFromGitHub` rev was updated but the hash wasn't
- A version bump was applied with a placeholder hash

## Fix Strategy

Replace the old hash with the correct one from the error output.

The error message always includes both:
```
  specified: sha256-OLD_HASH
  got:       sha256-CORRECT_HASH
```

Use the `got:` value as the replacement.

### In an overrideAttrs

```nix
package = prev.package.overrideAttrs (_old: {
  src = prev.fetchFromGitHub {
    owner = "owner";
    repo = "repo";
    rev = "vX.Y.Z";
    hash = "sha256-CORRECT_HASH";  # Updated from error output
  };
});
```

### Computing a Hash Manually

If you need to compute the hash before building:

```bash
# For GitHub archives
nix-prefetch-url --unpack https://github.com/owner/repo/archive/vX.Y.Z.tar.gz

# Convert to SRI format
nix hash to-sri --type sha256 <hash-from-above>
```

### Placeholder Trick

When creating a version bump and you don't know the hash yet, use an empty string:

```nix
hash = "";
```

The build will fail immediately with the correct hash in the error message.
