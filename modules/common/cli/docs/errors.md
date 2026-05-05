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
