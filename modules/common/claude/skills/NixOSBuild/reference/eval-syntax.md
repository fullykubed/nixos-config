# Fix Type: EVAL_SYNTAX

Nix evaluation failed due to invalid syntax in a .nix file.

## Error Patterns

- `error: syntax error, unexpected ...`
- `error: syntax error, unexpected ';', expecting '}'`
- `error: syntax error, unexpected ')', expecting ';'`
- `error: syntax error, unexpected end of file`

## Common Causes

1. **Missing semicolon** — after a `let` binding or attribute set entry
2. **Unmatched braces or brackets** — `{`, `[`, `(` without matching close
3. **Missing `in` after `let` block** — `let ... <missing in> ...`
4. **Stray comma** — Nix uses semicolons, not commas, to separate attrset entries
5. **Missing colon in function** — `{ arg } :` needs the colon, or `arg:` for simple functions
6. **String interpolation error** — malformed `${ }` inside strings

## Fix Strategies

### Use the error location

The error message includes `at /path/to/file.nix:line:col`. Open that file at the indicated position. The error is at or just before the reported location.

### Common fixes

**Missing semicolon**:
```nix
# Wrong
let
  x = 1
  y = 2
in x + y

# Correct
let
  x = 1;
  y = 2;
in x + y
```

**Missing `in`**:
```nix
# Wrong
let
  x = 1;
x + 1

# Correct
let
  x = 1;
in x + 1
```

**Comma instead of semicolon**:
```nix
# Wrong (not JSON)
{
  a = 1,
  b = 2,
}

# Correct
{
  a = 1;
  b = 2;
}
```

### Run the formatter

After fixing, run `nixfmt` on the file to catch any remaining syntax issues.
