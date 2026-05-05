import { Data } from "effect"

export class UnknownCommand extends Data.TaggedError("UnknownCommand")<{
  readonly input: string
  readonly available: readonly string[]
  readonly cause?: unknown
}> {}

export class UnknownFlag extends Data.TaggedError("UnknownFlag")<{
  readonly flag: string
  readonly command: string
  readonly cause?: unknown
}> {}

export class MissingArgument extends Data.TaggedError("MissingArgument")<{
  readonly name: string
  readonly command: string
  readonly cause?: unknown
}> {}

export class InvalidValue extends Data.TaggedError("InvalidValue")<{
  readonly flag: string
  readonly value: string
  readonly expected: string
  readonly cause?: unknown
}> {}

export class ParseError extends Data.TaggedError("ParseError")<{
  readonly message: string
  readonly cause?: unknown
}> {}

export class ValidationErrors extends Data.TaggedError("ValidationErrors")<{
  readonly errors: readonly InvalidValue[]
  readonly cause?: unknown
}> {}

export class ConflictingFlags extends Data.TaggedError("ConflictingFlags")<{
  readonly flags: readonly string[]
  readonly command: string
  readonly cause?: unknown
}> {}

export type CliError =
  | UnknownCommand
  | UnknownFlag
  | MissingArgument
  | InvalidValue
  | ParseError
  | ValidationErrors
  | ConflictingFlags