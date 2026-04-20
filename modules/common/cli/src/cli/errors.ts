import { Data } from "effect"

export class UnknownCommand extends Data.TaggedError("UnknownCommand")<{
  readonly input: string
  readonly available: readonly string[]
}> {}

export class UnknownFlag extends Data.TaggedError("UnknownFlag")<{
  readonly flag: string
  readonly command: string
}> {}

export class MissingArgument extends Data.TaggedError("MissingArgument")<{
  readonly name: string
  readonly command: string
}> {}

export class InvalidValue extends Data.TaggedError("InvalidValue")<{
  readonly flag: string
  readonly value: string
  readonly expected: string
}> {}

export class ParseError extends Data.TaggedError("ParseError")<{
  readonly message: string
}> {}

export type CliError =
  | UnknownCommand
  | UnknownFlag
  | MissingArgument
  | InvalidValue
  | ParseError