# Fix Type: EVAL_INFINITE_RECURSION

Nix evaluation failed due to a circular reference.

## Error Patterns

- `error: infinite recursion encountered`

## Common Causes

1. **Overlay uses `final` where it should use `prev`** — referencing the post-overlay package set when you need the pre-overlay version
2. **Two modules import each other** — circular `imports` lists
3. **Self-referencing `let` binding** — a `let` variable references itself
4. **Override cycle** — package A overrides package B which depends on package A's override

## Fix Strategies

### Overlay `final` vs `prev` rule

In an overlay `final: prev:`:
- Use `prev.package` to access the **unmodified** version of a package (before overlays)
- Use `final.package` only when you need the **post-overlay** result of a *different* package

**Wrong** (causes recursion):
```nix
myOverlay = final: prev: {
  foo = final.foo.overrideAttrs (old: { ... });  # final.foo IS this override
};
```

**Correct**:
```nix
myOverlay = final: prev: {
  foo = prev.foo.overrideAttrs (old: { ... });  # prev.foo is the original
};
```

### Cross-dependency in overlays

If package A needs the overlayed version of package B, and B needs the overlayed version of A, break the cycle by using `prev` for one of them:
```nix
myOverlay = final: prev: {
  a = prev.a.override { b = final.b; };  # A gets overlayed B
  b = prev.b.override { ... };            # B uses prev, no cycle
};
```

### Circular module imports

Remove the circular import. Extract shared config into a third module that both import instead.

### Self-referencing let

Replace with a two-step binding:
```nix
let
  base = <original value>;
  modified = <transform base>;
in modified
```
