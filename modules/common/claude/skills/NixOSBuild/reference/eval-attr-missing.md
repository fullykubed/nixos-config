# Fix Type: EVAL_ATTR_MISSING

Nix evaluation failed because an attribute or variable does not exist.

## Error Patterns

- `error: attribute '...' missing`
- `error: attribute '...' not found`
- `error: undefined variable '...'`

## Common Causes

1. **Package removed or renamed in nixpkgs** — upstream nixpkgs dropped or renamed a package
2. **Module option renamed or restructured** — a NixOS option path changed between releases
3. **Typo in attribute name** — simple misspelling in the configuration
4. **Attribute not in scope** — referencing an overlay-provided attribute before the overlay is applied
5. **Wrong package set** — referencing `pkgs.foo` when the package lives in `pkgs.pythonPackages.foo` or similar

## Fix Strategies

### Find the correct attribute name

1. Search nixpkgs for the package:
   ```bash
   nix eval --impure --expr 'builtins.attrNames (import <nixpkgs> {})' 2>/dev/null | rg '<name>'
   ```
2. Check the nixpkgs commit history or release notes for renames
3. Use `mcp__exa__web_search_exa` to search: `"<package-name> renamed nixpkgs"`

### Package removed — inherit from unstable

If the package was removed from the stable channel but exists in unstable:
```nix
# patches/default.nix
<package> = final.unstable.<package>;
```

### Module option renamed

Update the option path in the module configuration to match the new name. Check the NixOS option search or release notes.

### Typo

Fix the spelling. The error message includes the location (file:line:col).
