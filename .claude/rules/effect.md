---
paths:
  - "modules/common/cli/src/**/*.ts"
  - "modules/common/cli/src/**/*.tsx"
---

# Effect patterns for the CLI

## Errors are values — never use try/catch

`yield*` failures propagate through the Effect channel, not exceptions. A `try/catch` around a `yield*` silently swallows Effect failures and breaks the generator. Use `Effect.either`, `Effect.catchAll`, or `Effect.catchTag` instead.

```ts
// WRONG — catch never fires for Effect failures
try {
  const result = yield* someEffect
} catch (e) { ... }

// RIGHT
const result = yield* someEffect.pipe(Effect.either)
if (Either.isLeft(result)) { /* handle error */ }

// RIGHT
const result = yield* someEffect.pipe(
  Effect.catchTag("SomeError", (err) => ...)
)
```

## Use Either.isRight / Either.isLeft — never check _tag directly

```ts
// WRONG
if (result._tag === "Right") { ... }

// RIGHT
if (Either.isRight(result)) { ... }
```

## Use @effect/platform FileSystem — never import fs or shell out to filesystem commands

All local file I/O must go through the `FileSystem` service from `@effect/platform`. This keeps effects composable and testable via Layer injection. Never import `fs`/`node:fs`, and never shell out to `mkdir`, `rmdir`, `rm`, `cat`, `ls`, `stat`, `cp`, `mv`, `touch`, or `chmod` — use the equivalent FileSystem method.

```ts
import { FileSystem } from "@effect/platform"

const fs = yield* FileSystem.FileSystem
const content = yield* fs.readFileString("/path/to/file")
yield* fs.writeFileString("/tmp/out.txt", data)
yield* fs.remove("/tmp/out.txt")
const exists = yield* fs.exists("/some/path")
yield* fs.makeDirectory("/tmp/lockdir")        // atomic, like shell mkdir
yield* fs.rename("/tmp/old", "/tmp/new")       // instead of shell mv
yield* fs.copy("/src/file", "/dst/file")       // instead of shell cp
yield* fs.readDirectory("/some/dir")           // instead of shell ls
```

Note: remote SSH commands running on builders are fine — this rule applies to **local** filesystem operations only.

## Use makeTempFileScoped for temporary files

Never manually create and clean up temp files. Use `fs.makeTempFileScoped()` inside an `Effect.scoped` block — the file is automatically deleted when the scope closes, even on failure or interruption.

```ts
const result = yield* Effect.scoped(
  Effect.gen(function* () {
    const fs = yield* FileSystem.FileSystem
    const tmpFile = yield* fs.makeTempFileScoped({ directory: "/tmp", prefix: "my-prefix-" })
    yield* fs.writeFileString(tmpFile, content)
    // ... use tmpFile ...
    return value
  })
)
// tmpFile is already deleted here
```

## Use Effect.log — never use console

All logging goes through the Effect logger (`Effect.log`, `Effect.logWarning`, `Effect.logError`). A custom CLI logger in `lib/logger.ts` routes info to stdout and warnings/errors to stderr with ANSI colors.

```ts
yield* Effect.log("progress message")            // stdout, plain
yield* Effect.logWarning("something is off")      // stderr, yellow
yield* Effect.logError("something failed")        // stderr, red
```

For structured command output (tables, JSON), use `table()` / `json()` from `lib/output.ts` — these write directly to `process.stdout` and are not logs.

## Use Effect.retry with Schedule — never write manual retry loops

Never use `for`/`while` loops with `Effect.sleep` for retries or polling. Use `Effect.retry` with `Schedule` combinators.

```ts
// WRONG — manual retry loop
for (let attempt = 0; attempt < 12; attempt++) {
  const result = yield* someEffect.pipe(Effect.either)
  if (Either.isRight(result)) break
  yield* Effect.sleep("5 seconds")
}

// RIGHT — retry 12 times with 5s between attempts
yield* someEffect.pipe(
  Effect.retry(Schedule.spaced("5 seconds").pipe(Schedule.intersect(Schedule.recurs(11))))
)
```

Common patterns:
- **Fixed delay + max retries**: `Schedule.spaced("5 seconds").pipe(Schedule.intersect(Schedule.recurs(N)))`
- **Log on retry**: `Schedule.tapInput(() => Effect.logWarning("retrying..."))`
- **Polling until success**: make the check fail when condition isn't met, then retry
- **Non-fatal timeout**: wrap in `Effect.catchAll(() => Effect.succeed(fallback))`

## Wrap errors with cause — never interpolate inner error messages

When catching errors from a dependency and re-wrapping into a domain error, pass the original error as `cause` instead of interpolating its message into the new error's message string. This preserves the full error tree for debugging while keeping the domain error's message a clean, static description of what went wrong at this level.

```ts
// WRONG — duplicates inner error text into message
Effect.catchAll((err) =>
  Effect.fail(new BuilderCreateError({
    name,
    message: `Failed to mint key: ${String(err)}`,
  }))
)

// RIGHT — static message, original error preserved via cause
Effect.catchAll((err) =>
  Effect.fail(new BuilderCreateError({
    name,
    message: "Failed to mint pre-auth key",
    cause: err,
  }))
)
```

Define `cause` as optional on error classes that wrap downstream failures:

```ts
export class BuilderCreateError extends Data.TaggedError("BuilderCreateError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}
```

Errors that don't wrap a downstream failure (e.g. "no snapshot found") omit `cause` — the message alone is sufficient.

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

## Service pattern

Services are defined as tagged Context values with a `Live` Layer. Tests provide mock Layers.

```ts
// Define
export class MyService extends Context.Tag("MyService")<MyService, MyServiceShape>() {}
export const MyServiceLive = Layer.effect(MyService, Effect.gen(function* () { ... }))

// Use
const svc = yield* MyService

// Test
const MockMyService = Layer.succeed(MyService, { ... })
await Effect.runPromise(myEffect.pipe(Effect.provide(MockMyService)))
```

## Use Bun.color() — never write manual ANSI escape codes

For terminal coloring outside of OpenTUI components, use `Bun.color(name, "ansi")` instead of raw ANSI escape codes. This is more readable and maintainable.

```ts
// WRONG
const RED = "\x1b[31m"
const text = `${RED}error${"\x1b[0m"}`

// RIGHT
const RED = Bun.color("red", "ansi")
const RESET = "\x1b[0m"
const text = `${RED}error${RESET}`
```

For OpenTUI components (`.tsx` files), use `@opentui/core` color functions (`red()`, `green()`, `bold()`, etc.) with `StyledText` instead.

## Enforced by ESLint

These patterns are enforced by lint rules in `eslint.config.ts`:
- `no-restricted-syntax: TryStatement` — bans try/catch
- `no-restricted-syntax: _tag === 'Right'/'Left'` — bans direct tag checks
- `no-restricted-syntax: mkdir/rmdir/rm/cat/ls/stat/cp/mv/touch/chmod` — bans shelling out to filesystem commands
- `no-restricted-imports: fs, node:fs, node:fs/promises` — bans Node.js fs
- `no-console` — bans console.log/error/warn (use Effect.log instead)
