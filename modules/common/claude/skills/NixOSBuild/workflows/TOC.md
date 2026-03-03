# workflows/

The core build-fix loop and review procedures.

- `Build.md` — Execute nix build, parse errors, consult reference handlers, apply fixes, and retry until success or attempt limit.
- `ReviewAutofixes.md` — Present each uncommitted autofix to the user for approval, rejection, or editing, then commit approved fixes and revert rejected ones.
