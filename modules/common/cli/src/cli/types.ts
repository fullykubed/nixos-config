import type { Effect } from "effect"

/**
 * Identity function that provides contextual typing for command definitions.
 * Infers E (errors) from the handler's return type while constraining
 * flags/args to their proper discriminated-union types.
 */
export function defineCommand<E>(def: Command<E>): Command<E> {
  return def
}

/** Extract the error type from a Command. */
type CommandE<C> = C extends Command<infer E> ? E : never

/**
 * Build a ReadonlyMap of commands from entries, unifying each command's
 * E into a single Command type.  Uses `const T` to preserve the
 * exact tuple, then conditional types to compute the union of all error
 * types.  This works because Command is covariant in E
 * (handler returns Effect<void, E>), so each individual
 * Command<Ei> is assignable to Command<UnionE>.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function commandMap<const T extends readonly (readonly [string, Command<any>])[]>(
  entries: T
): ReadonlyMap<string, Command<CommandE<T[number][1]>>> {
  return new Map(entries) as ReadonlyMap<string, Command<CommandE<T[number][1]>>>
}

export interface BooleanFlag {
  readonly kind: "boolean"
  readonly name: string
  readonly short?: string
  readonly description: string
  readonly default: boolean
}

export interface StringFlag {
  readonly kind: "string"
  readonly name: string
  readonly short?: string
  readonly description: string
  readonly required: boolean
  readonly choices?: readonly string[]
  readonly default?: string
}

export type Flag = BooleanFlag | StringFlag

export interface PositionalArg {
  readonly name: string
  readonly description: string
  readonly required: boolean
  readonly variadic?: boolean
}

export interface Command<E = never> {
  readonly name: string
  readonly description: string
  readonly flags: readonly Flag[]
  readonly args: readonly PositionalArg[]
  readonly handler: (parsed: ParsedCommand) => Effect.Effect<void, E>
}

export interface CommandGroup<E = never> {
  readonly name: string
  readonly description: string
  readonly commands: ReadonlyMap<string, Command<E>>
}

export interface CommandRegistry<E = never> {
  readonly groups: ReadonlyMap<string, CommandGroup<E>>
  readonly globalFlags: readonly Flag[]
}

export interface ParsedCommand {
  readonly group: string
  readonly command: string
  readonly flags: ReadonlyMap<string, string | boolean>
  readonly args: readonly string[]
  readonly raw: readonly string[]
}
