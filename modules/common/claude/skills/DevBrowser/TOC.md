# DevBrowser/

Browser automation skill using headless Chromium with a WebSocket-based server/client architecture.

- `SKILL.md` — Skill definition with CLI commands (navigate, click, type, screenshot, eval, wait) and workflow routing.
- `default.nix` — Nix derivation using bun2nix to build the TypeScript CLI; wraps Chromium and exports binaries.
- `package.json` — NPM manifest declaring TypeScript, Playwright, and build dependencies.
- `bun.nix` — Pre-fetched Bun dependencies for network-free Nix builds.
- `bun.lock` — Bun lockfile pinning dependency versions.
- `tsconfig.json` — TypeScript compiler configuration.
- `src/` — TypeScript source implementing the browser CLI, WebSocket server/client, and DOM snapshotting.
- `workflows/` — Step-by-step procedures for using DevBrowser.
