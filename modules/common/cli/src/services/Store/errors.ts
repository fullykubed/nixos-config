import { Data } from "effect"

export class StoreError extends Data.TaggedError("StoreError")<{
  readonly operation: string
  readonly message: string
  readonly path?: string
  readonly cause?: unknown
}> {}
