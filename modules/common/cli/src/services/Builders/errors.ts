import { Data } from "effect"

/** The raw input did not resolve to a valid builder name. */
export class InvalidBuilderNameError extends Data.TaggedError("InvalidBuilderNameError")<{
  readonly input: string
  readonly cause?: unknown
}> {}

/** No builder with this name exists in Hetzner Cloud. */
export class BuilderNotFoundError extends Data.TaggedError("BuilderNotFoundError")<{
  readonly name: string
  readonly cause?: unknown
}> {}

/** The builder's Tailscale IP could not be resolved. */
export class BuilderUnreachableError extends Data.TaggedError("BuilderUnreachableError")<{
  readonly name: string
  readonly reason: string
  readonly cause?: unknown
}> {}

/** A builder could not be fully destroyed. */
export class BuilderDestroyError extends Data.TaggedError("BuilderDestroyError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

/** Builder creation failed at some stage. */
export class BuilderCreateError extends Data.TaggedError("BuilderCreateError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}
