import { Data } from "effect"

/** TCP connection could not be established (refused, no route, generic failure). */
export class SshConnectionError extends Data.TaggedError("SshConnectionError")<{
  readonly host: string
  readonly exitCode: number
  readonly stderr: string
  readonly cause?: unknown
}> {}

/** Authentication was rejected by the remote host (wrong key, permission denied). */
export class SshAuthError extends Data.TaggedError("SshAuthError")<{
  readonly host: string
  readonly stderr: string
  readonly cause?: unknown
}> {}

/** The SSH connection timed out before the handshake completed. */
export class SshTimeoutError extends Data.TaggedError("SshTimeoutError")<{
  readonly host: string
  readonly timeout: number
  readonly cause?: unknown
}> {}

/** The remote host key didn't match the expected key in known_hosts. */
export class SshHostKeyError extends Data.TaggedError("SshHostKeyError")<{
  readonly host: string
  readonly stderr: string
  readonly cause?: unknown
}> {}