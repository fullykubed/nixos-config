import { Data } from "effect"

/** The croc relay is not reachable (TCP connectivity check failed). */
export class CrocRelayUnreachableError extends Data.TaggedError("CrocRelayUnreachableError")<{
  readonly relayAddress: string
  readonly cause?: unknown
}> {}

/** Failed to read the croc relay password from the agenix secret. */
export class CrocRelayPassError extends Data.TaggedError("CrocRelayPassError")<{
  readonly path: string
  readonly message: string
  readonly cause?: unknown
}> {}

/** Failed to generate a croc transfer code. */
export class CrocCodeError extends Data.TaggedError("CrocCodeError")<{
  readonly message: string
  readonly cause?: unknown
}> {}

/** croc send failed after all retry attempts. */
export class CrocSendError extends Data.TaggedError("CrocSendError")<{
  readonly target: string
  readonly attempts: number
  readonly message: string
  readonly cause?: unknown
}> {}