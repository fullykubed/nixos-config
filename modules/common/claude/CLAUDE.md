# IMPORTANT

- When in a git worktree, scope changes primarily to that worktree unless explicitly instructed by the user otherwise.
- When stuck on implementing code or configuration changes, use the Exa code research tool (mcp__exa__get_code_context_exa) to find relevant examples, API documentation, and solutions.
- When exploring an unfamiliar directory, check for a `TOC.md` file first. Most directories contain one describing each immediate child in 1-2 sentences. Read it before diving into individual files.
- When searching for files in `/nix/store`, use `locate` (plocate) instead of `find` or `fd`. The plocate database indexes the entire Nix store and is updated reactively on store changes. Example: `locate -i libssl.so` instead of `find /nix/store -name 'libssl.so'`.
