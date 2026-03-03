# workflows/

The core build-fix loop procedure.

- `Build.md` — Execute nix build, parse errors, consult reference handlers, apply fixes, and retry until success or attempt limit.
