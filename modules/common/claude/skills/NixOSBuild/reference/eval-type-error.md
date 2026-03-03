# Fix Type: EVAL_TYPE_ERROR

Nix evaluation failed because a value of the wrong type was used.

## Error Patterns

- `error: value is a string while a set was expected`
- `error: value is a set while a list was expected`
- `error: value is a list while a string was expected`
- `error: value is a ... while a ... was expected`
- `error: cannot coerce ... to a string`

## Common Causes

1. **String where a list is expected** — passing `"foo"` instead of `[ "foo" ]`
2. **List where an attrset is expected** — passing `[ ... ]` where `{ ... }` is needed
3. **Package where a string is expected** — passing `pkgs.foo` where `"${pkgs.foo}"` or a path is needed
4. **String where a package is expected** — passing `"foo"` where `pkgs.foo` is needed
5. **Wrong option type in module** — the NixOS option definition expects a different type

## Fix Strategies

### Check the option type

Look up the NixOS option definition to see what type it expects:
- `types.listOf types.str` → needs `[ "value" ]`
- `types.attrsOf types.str` → needs `{ key = "value"; }`
- `types.package` → needs `pkgs.something`
- `types.str` → needs `"value"`
- `types.path` → needs `/path/to/something` or `./relative`

### Wrap or unwrap values

- String → list: wrap in `[ ]`
- Package → string: use `"${pkg}"` or `lib.getExe pkg` or `lib.getBin pkg`
- String → package: replace with `pkgs.<name>`

### Check function arguments

If the error is in an overlay or override, verify the function signature matches what the caller provides. A common mistake is passing an attrset to a function that expects individual arguments or vice versa.
