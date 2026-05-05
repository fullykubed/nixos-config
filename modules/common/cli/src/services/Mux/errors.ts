import { Data } from "effect"

export class MuxStoreError extends Data.TaggedError("MuxStoreError")<{
  readonly operation: string
  readonly message: string
  readonly project_path?: string
  readonly branch?: string
  readonly cause?: unknown
}> {}

export class MuxProjectNotFoundError extends Data.TaggedError("MuxProjectNotFoundError")<{
  readonly id: string
  readonly cause?: unknown
}> {}

export class MuxBranchExistsOnRemoteError extends Data.TaggedError("MuxBranchExistsOnRemoteError")<{
  readonly branch: string
  readonly cause?: unknown
}> {}

export class MuxBranchExistsLocallyError extends Data.TaggedError("MuxBranchExistsLocallyError")<{
  readonly branch: string
  readonly hasWorktree: boolean
  readonly cause?: unknown
}> {}

export class MuxWorktreePathConflictError extends Data.TaggedError("MuxWorktreePathConflictError")<{
  readonly path: string
  readonly cause?: unknown
}> {}

export class MuxCreateWorktreeError extends Data.TaggedError("MuxCreateWorktreeError")<{
  readonly branch: string
  readonly cause?: unknown
}> {}

export class MuxInitWorktreeError extends Data.TaggedError("MuxInitWorktreeError")<{
  readonly message: string
  readonly paths?: readonly string[]
  readonly cause?: unknown
}> {}

export class MuxTmuxSyncError extends Data.TaggedError("MuxTmuxSyncError")<{
  readonly message: string
  readonly cause?: unknown
}> {}
