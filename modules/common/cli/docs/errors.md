# Error Patterns (`Data.TaggedError`)

Each service defines its errors in `errors.ts`. Every error extends `Data.TaggedError` with a unique string tag. Fields carry enough context to produce a useful message.

```ts
// services/Builders/errors.ts
import { Data } from "effect"

export class BuilderNotFoundError extends Data.TaggedError("BuilderNotFoundError")<{
  readonly name: string
  readonly cause?: unknown
}> {}

export class BuilderCreateError extends Data.TaggedError("BuilderCreateError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}
```

The tag string (`"BuilderNotFoundError"`) is used for pattern-matching with `Effect.catchTag`. The optional `cause` field chains underlying errors.

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

## Reclassifying errors with `reclassify`

When a service catches errors from a dependency and maps them to its own domain errors (e.g. `ShellError` → `GitError`), the new error normally captures a fresh JS stack and span annotation pointing at the classification code — not the original failure site. Use `reclassify` (`src/lib/reclassify.ts`) to preserve the original error's stack trace and Effect span annotation on the new error:

```ts
import { reclassify } from "../../lib/reclassify"

export const toGitError = (e: ShellError) =>
  Effect.fail(reclassify(e, classifyGitError))
```

`reclassify(source, classify)` does three things:
1. Sets `Error.stackTraceLimit = 0` so the new error skips stack capture (perf)
2. Calls `classify(source)` to produce the new error
3. Copies the source's JS `.stack` and Effect span annotation onto the result

This ensures the reclassified error's trace shows the original call chain through service spans rather than the classification internals.
