import { Data } from "effect"

/** The local Tailscale daemon is not in the "Running" state. */
export class TailscaleNotConnectedError extends Data.TaggedError("TailscaleNotConnectedError")<{
  readonly backendState: string
  readonly message: string
  readonly cause?: unknown
}> {}

/** `tailscale ip -4 <hostname>` failed — the builder isn't registered or DNS hasn't propagated. */
export class TailscaleDNSResolutionError extends Data.TaggedError("TailscaleDNSResolutionError")<{
  readonly hostname: string
  readonly error: string
  readonly cause?: unknown
}> {}

/** A Tailscale operation exceeded its deadline.  (Currently unused but reserved.) */
export class TailscaleTimeoutError extends Data.TaggedError("TailscaleTimeoutError")<{
  readonly operation: string
  readonly timeout: number
  readonly cause?: unknown
}> {}

/** Failed to mint a Headscale pre-auth key. */
export class HeadscalePreAuthError extends Data.TaggedError("HeadscalePreAuthError")<{
  readonly message: string
  readonly cause?: unknown
}> {}

/** Failed to delete a Headscale node. */
export class HeadscaleNodeError extends Data.TaggedError("HeadscaleNodeError")<{
  readonly hostname: string
  readonly message: string
  readonly cause?: unknown
}> {}

/** Union of all Tailscale-specific error types. */
export type TailscaleError =
  | TailscaleNotConnectedError
  | TailscaleDNSResolutionError
  | TailscaleTimeoutError
  | HeadscalePreAuthError
  | HeadscaleNodeError