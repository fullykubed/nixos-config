# Core Conventions

## Never annotate `Effect.Effect` return types

Do not write explicit `Effect.Effect<A, E, R>` return types on functions. Let TypeScript infer the return type from the implementation. This ensures the error channel (`E`) and requirements channel (`R`) always reflect what the function actually does — adding a dependency or a new error path automatically updates the type without manual bookkeeping.

```ts
// good — inferred return type
export const exists = (name: string) =>
  Effect.gen(function* () {
    const hcloud = yield* HcloudService
    return yield* hcloud.serverExists(name)
  })

// bad — explicit return type can silently drift from implementation
export const exists = (name: string): Effect.Effect<boolean, never, HcloudService> =>
  Effect.gen(function* () {
    const hcloud = yield* HcloudService
    return yield* hcloud.serverExists(name)
  })
```

This applies everywhere: service methods, handlers, internal helpers. The same principle drives the derived-type pattern in service files (see [services.md](services.md)).

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

