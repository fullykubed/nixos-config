# `j` CLI

## Directory Structure

```
src/
├── main.ts                    Entry point: argv parsing, error formatting, signal handling
├── cli/
│   ├── types.ts               Command/flag/arg type definitions, defineCommand helper
│   ├── parser.ts              Argv parser (groups, commands, flags, args)
│   ├── help.ts                Help text formatters (top-level, group, command)
│   └── errors.ts              Parse error types (UnknownCommand, MissingArgument, etc.)
├── commands/
│   └── builders/
│       ├── index.ts           Command group registration (10 subcommands)
│       ├── types.ts           Builder-specific view types
│       └── <cmd>/
│           ├── command.ts     Declarative command definition (flags, args, handler)
│           └── handler.ts     Effect-based handler implementation
├── services/
│   ├── layers.ts              Pre-composed Layer combinations (BaseLive, BuildersFullLive)
│   ├── Store.ts               SQLite store (Kysely + migrations)
│   ├── db.ts                  Database schema type (Kysely)
│   ├── Shell/                 Subprocess execution
│   ├── Lock/                  Advisory locking
│   ├── Hcloud/                Hetzner Cloud API
│   ├── Tailscale/             Tailscale/Headscale operations
│   ├── Ssh/                   SSH execution and interactive sessions
│   ├── Croc/                  Secure file transfer
│   └── Builders/              High-level builder lifecycle
└── lib/
    ├── logger.ts              Effect logger (minimal, stderr)
    └── output.ts              Output formatting utilities
```
