import { Data } from "effect"
import type { StoreError } from "../Store"

export class LockAcquireError extends Data.TaggedError("LockAcquireError")<{
  readonly name: string
  readonly message: string
  readonly cause?: StoreError
}> {}

export class LockCheckError extends Data.TaggedError("LockCheckError")<{
  readonly name: string
  readonly message: string
  readonly cause: StoreError
}> {}

export class LockReleaseError extends Data.TaggedError("LockReleaseError")<{
  readonly name: string
  readonly message: string
  readonly cause: StoreError
}> {}

export interface LockAcquireInfo {
  readonly waited: boolean
  readonly attempts: number
}