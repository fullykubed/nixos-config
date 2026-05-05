# `j` CLI

Swiss-army knife CLI consolidating all custom scripts and system tooling into a single binary. 

## Technology Stack

| Layer | Technology | Role |
|---|---|---|
| Runtime | [Bun](https://bun.sh) 1.x | JS runtime, SQLite driver, standalone compiler |
| Effect system | [Effect](https://effect.website) 3.x | Typed errors, dependency injection, concurrency |
| TUI | [OpenTUI](https://opentui.dev) + [Solid](https://solidjs.com) | Reactive terminal UI (dashboard) |
| Storage | Kysely + bun:sqlite | Local state (locks) at `$XDG_STATE_HOME/j/cli.db` |
| Build | bun2nix | Nix derivation from `bun.lock` |

## References

- [Building and testing](../../modules/common/cli/docs/building-and-testing.md) — build, test, lint, typecheck, and Nix derivation
- [Remote builders](../build-system/remote-builders/README.md) — how the builder fleet works end-to-end
