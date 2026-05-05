# Service Patterns

Every service under `src/services/` follows the same structure. This document describes each piece of the pattern with inline examples drawn from real services.

## Directory layout

A service `Xyz` lives in `src/services/Xyz/` with these files:

```
services/Xyz/
  errors.ts          # Tagged error classes
  types.ts           # Domain interfaces, branded types (optional)
  config.ts          # Constants or runtime config loading (optional)
  Xyz.ts             # Service tag, make effect, Layer
  index.ts           # Barrel re-exports
  public/            # One exported function per method
    foo.ts
    bar.ts
    foo.test.ts      # Unit test per method
    bar.test.ts
  internal/          # Shared helpers not exposed in the service interface (optional)
    baz.ts
    baz.test.ts
  integration-tests/ # Real-resource tests in tmpdir (optional)
    setup.ts
    *.test.ts
```

## Service file (`Xyz.ts`)

The service file ties everything together: it defines the service tag, builds the layer, and wires method functions to the DI context. Always use the `make` + derived type pattern:

```ts
// services/Xyz/Xyz.ts
import { Context, Effect, Layer } from "effect"
import { mkContextInjector } from "../../lib/mkContextInjector"
import { DepA } from "../DepA"
import { DepB } from "../DepB"
import { foo } from "./public/foo"
import { bar } from "./public/bar"

const make = Effect.gen(function* () {
  const depA = yield* DepA
  const depB = yield* DepB
  const ctx = Context.empty().pipe(
    Context.add(DepA, depA),
    Context.add(DepB, depB),
  )
  const inject = mkContextInjector(ctx, "Xyz")

  return {
    foo: inject(foo),
    bar: inject(bar),
  }
})

export type XyzServiceShape = Effect.Effect.Success<typeof make>

export class XyzService extends Context.Tag("XyzService")<
  XyzService,
  XyzServiceShape
>() {}

export const XyzLive = Layer.effect(XyzService, make)
```

`Effect.Effect.Success<typeof make>` derives the shape type from the make effect's return value. This prevents a class of bugs where an explicit interface silently narrows or widens the type channels — the derived type always matches what `make` actually returns.

### `mkContextInjector` and span tracing

`mkContextInjector(ctx, "ServiceName")` does two things:

1. **Provides context** — wraps each method so its dependency requirements (`R`) are pre-provided, keeping the service interface clean.
2. **Adds span tracing** — wraps each method with `Effect.withSpan` using a custom `captureStackTrace` that records both the **wiring site** (where `inject(fn)` is called in the service file) and the **call site** (where the method is invoked at runtime). The span name is derived automatically from `fn.name` (e.g. `inject(repoRoot)` produces a span named `Git.repoRoot`).

This means error traces show the full call chain through service boundaries without any manual span annotations in method files:

```
GitUnknownError: ...
    at Git.repoRoot (Git.ts:50:15)           ← wiring site
    at Git.repoRoot (get-worktree.ts:9:33)    ← call site
    at Mux.getWorktree (Mux.ts:46:26)        ← wiring site
    at Mux.getWorktree (handler.ts:47:25)     ← call site
```

Non-Effect values (constants, pure functions) can be included in the return object without `inject` — they just won't get spans.

## Types (branded types, domain interfaces)

`types.ts` defines domain interfaces and branded ID types. Branded types prevent mixing up plain numbers that represent different entities.

```ts
// services/Hcloud/types.ts
import { Brand } from "effect"

export type ServerId = number & Brand.Brand<"ServerId">
export const ServerId = Brand.nominal<ServerId>()

export interface Server {
  readonly id: ServerId
  readonly name: string
  readonly status: "running" | "starting" | "stopping" | "off" | ...
  readonly created: string
  readonly labels: Record<string, string>
}
```

Only create a `types.ts` when needed to break circular imports between method files or to share types with consumers outside the service.

## Method files (one function per file)

Each public method is a single exported function in its own file under `public/`. The function uses `yield*` to pull dependencies from Effect context — never constructor injection, never globals.

Key rules:
- **One function, one file.** The filename matches the function name (`serverExists` → `server-exists.ts`).
- **Cross-method calls** import the function directly, not through the service tag. Context threads through automatically since both functions yield from the same tags.

```ts
// services/Builders/public/create.ts  (calling isReady from ./is-ready.ts)
import { isReady } from "./is-ready"

export const create = (name: string) =>
  Effect.gen(function* () {
    // ... setup ...
    yield* isReady(name).pipe(
      Effect.flatMap((ready) => ready ? Effect.void : Effect.fail("not ready" as const)),
      Effect.retry(Schedule.spaced("5 seconds").pipe(Schedule.upTo("180 seconds"))),
    )
  })
```

## Internal utilities (`internal/`)

Shared helper functions that are used by multiple methods but are not part of the service's public interface live in `internal/`. These are never wired through `inject` or exposed on the service shape — method files import them directly.

```ts
// services/Builders/internal/ensure-ccache-volume.ts
import { Effect } from "effect"
import { HcloudService } from "../../Hcloud"

export const ensureCcacheVolume = (name: string) =>
  Effect.gen(function* () {
    const hcloud = yield* HcloudService
    // ...
  })
```

```ts
// services/Builders/public/create.ts
import { ensureCcacheVolume } from "../internal/ensure-ccache-volume"
```

If a helper is only used by a single method, keep it as a local function in that method file instead.

## `index.ts` barrel

The barrel re-exports only the public API: the service tag, the live layer, and any types/errors consumers need.

```ts
// services/Builders/index.ts
export {
  BuildersService,
  BuildersLive,
  type BuilderStats,
} from "./Builders"
export { BUILDER_CONFIG } from "./config"
```

Keep it minimal — internal method files and test helpers are never re-exported.

## Never use Effect.orDie in services

Services must propagate errors through the typed error channel, never convert them to defects with `Effect.orDie`. Defects bypass all typed error handling and crash the fiber. If a service operation can fail, reflect that in the return type.

```ts
// WRONG — crashes the fiber if listServers fails
list: () => hcloud.listServers().pipe(Effect.orDie)

// RIGHT — let HcloudError propagate
list: () => hcloud.listServers().pipe(
  Effect.map(servers => servers.filter(...))
)
```

## Layer composition (`layers.ts`)

`src/services/layers.ts` composes individual service layers into ready-to-use bundles (`BaseLive`, `BuildersFullLive`, `MuxFullLive`, etc.) that command handlers provide at the top level. See the file header comment for ordering conventions.

## Errors (`errors.ts`)

Each service defines its errors in `errors.ts` using `Data.TaggedError`. Services should not allow errors from their requirements to bubble through — catch dependency errors and wrap them in the service's own domain errors. See [errors.md](errors.md) for the full pattern and error wrapping conventions.

## Testing

Every service must have integration tests. Integration tests use real resources (temp directories, git repos, tmux sessions, SQLite databases, etc.) but run completely locally — never against remote APIs or cloud infrastructure. They must not mutate the host operating system and must run in a completely sandboxed manner (temp directories, isolated sessions, in-memory databases). They live in `integration-tests/` with a `setup.ts` that creates and tears down real resources.

See [testing.md](testing.md) for unit tests, `test-helpers.ts` mock factories, and integration test patterns.
