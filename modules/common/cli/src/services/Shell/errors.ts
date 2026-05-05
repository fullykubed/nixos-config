import { Data } from "effect"

/** Raised when a shell command exits non-zero or times out. */
export class ShellError extends Data.TaggedError("ShellError")<{
  readonly command: string
  readonly exitCode: number
  readonly stdout: string
  readonly stderr: string
  readonly cause?: unknown
}> {}

/** Raised when execJson succeeds at running the command but fails to parse its stdout as JSON. */
export class JsonParseError extends Data.TaggedError("JsonParseError")<{
  readonly command: string
  readonly raw: string
  readonly error: string
  readonly cause?: unknown
}> {}
