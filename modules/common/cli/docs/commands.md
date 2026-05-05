# Commands

## Directory structure mirrors CLI invocation

The filesystem path under `src/commands/` matches the command's invocation path. For `j <group> <command>`, the definition lives at `src/commands/<group>/<command>/command.ts`.

Example: `j builders check` → `src/commands/builders/check/command.ts`

## Command groups via `index.ts`

Each directory level under `src/commands/` defines a command group. The group is registered in the directory's `index.ts`, which imports all child commands and exposes them via `commandMap`.

```ts
// src/commands/builders/index.ts
import { commandMap } from "../../cli/types"
import { checkCommand } from "./check/command"
import { createCommand } from "./create/command"

export const buildersGroup = {
  name: "builders",
  description: "Manage remote builder VMs",
  commands: commandMap([
    ["check", checkCommand],
    ["create", createCommand],
  ])
}
```

## Separation of command definition and handler logic

`command.ts` files only expose the declarative command definition via `defineCommand` (name, description, flags, args). The actual logic lives in a sibling `handler.ts` file. The command file references the handler but contains no business logic itself.

## Lazy-loaded handlers

Handlers and service layers are loaded via dynamic `import()` inside the handler body, not as static imports at the top of the file. This keeps the startup import graph small — help, completions, and parse-error paths never load service modules.

```ts
// src/commands/builders/list/command.ts
import { Effect } from "effect"
import { defineCommand } from "../../../cli/types"

export const listCommand = defineCommand({
  name: "list",
  description: "List all active builder VMs",
  flags: [{ kind: "boolean", name: "json", description: "Output results as JSON", default: false }],
  args: [],
  handler: (parsed) =>
    Effect.gen(function* () {
      const [{ listHandler }, { BuildersFullLive }] = yield* Effect.all([
        Effect.promise(() => import("./handler")),
        Effect.promise(() => import("../../../services/layers"))
      ], { concurrency: "unbounded" })
      yield* listHandler(parsed).pipe(Effect.provide(BuildersFullLive))
    })
})
```

The only static imports in a `command.ts` are `Effect` and `defineCommand`. Everything else — the handler function, the service layer, and their transitive dependencies — is deferred until the command actually runs. The two dynamic imports run concurrently via `Effect.all` with unbounded concurrency.
