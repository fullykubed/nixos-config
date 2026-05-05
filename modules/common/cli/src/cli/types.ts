import type { Effect } from "effect"

// ── Type-level inference utilities ────────────────────────────────────

/** Map a single Flag definition to its runtime value type. */
type FlagValue<F extends Flag> =
  F extends BooleanFlag ? boolean :
  F extends { kind: "string"; required: true; brand: (raw: string) => infer B } ? B :
  F extends { kind: "string"; default: string; brand: (raw: string) => infer B } ? B :
  F extends { kind: "string"; brand: (raw: string) => infer B } ? B | undefined :
  F extends { kind: "string"; required: true } ? string :
  F extends { kind: "string"; default: string } ? string :
  F extends { kind: "string" } ? string | undefined :
  F extends { kind: "integer"; required: true } ? number :
  F extends { kind: "integer"; default: number } ? number :
  F extends { kind: "integer" } ? number | undefined :
  never

/** Map a flags tuple to a named-property object. */
type InferFlags<F extends readonly Flag[]> = {
  readonly [K in F[number] as K["name"]]: FlagValue<K>
}

/** Map an args tuple to a named-property object. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type InferArgs<A extends readonly PositionalArg<any>[]> = {
  readonly [K in A[number] as K["name"]]:
    K extends { required: true; brand: (raw: string) => infer B } ? B :
    K extends { required: true } ? string :
    K extends { brand: (raw: string) => infer B } ? B | undefined :
    string | undefined
}

/** Typed parsed result that a defineCommand handler receives. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export interface TypedParsed<F extends readonly Flag[], A extends readonly PositionalArg<any>[]> {
  readonly group: string
  readonly command: string
  readonly flags: InferFlags<F>
  readonly args: InferArgs<A>
  readonly raw: readonly string[]
}

// ── defineCommand ─────────────────────────────────────────────────────

/**
 * Identity function that provides contextual typing for command definitions.
 * Uses `const` generics to preserve literal flag/arg tuples so that the
 * handler callback sees narrowed types (e.g. `parsed.flags.json` is `boolean`).
 */
export function defineCommand<
  const F extends readonly Flag[],
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const A extends readonly PositionalArg<any>[],
  E,
>(def: {
  readonly name: string
  readonly description: string
  readonly flags: F
  readonly args: A
  readonly handler: (parsed: TypedParsed<F, A>) => Effect.Effect<void, E>
}): Command<E> {
  // The cast is safe: at runtime ParsedCommand is a superset of TypedParsed.
  return def as unknown as Command<E>
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

// ── Flag / Arg definitions ────────────────────────────────────────────

export interface BooleanFlag {
  readonly kind: "boolean"
  readonly name: string
  readonly short?: string
  readonly description: string
  readonly default: boolean
}

export interface StringFlag<B = string> {
  readonly kind: "string"
  readonly name: string
  readonly short?: string
  readonly description: string
  readonly required: boolean
  readonly choices?: readonly string[]
  readonly default?: string
  readonly brand?: (raw: string) => B
}

export interface IntegerFlag {
  readonly kind: "integer"
  readonly name: string
  readonly short?: string
  readonly description: string
  readonly required: boolean
  readonly default?: number
  readonly min?: number
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type Flag = BooleanFlag | StringFlag<any> | IntegerFlag

export interface PositionalArg<B = string> {
  readonly name: string
  readonly description: string
  readonly required: boolean
  readonly variadic?: boolean
  readonly brand?: (raw: string) => B
}

// ── Command / Registry types ──────────────────────────────────────────

export interface Command<E = never> {
  readonly name: string
  readonly description: string
  readonly flags: readonly Flag[]
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  readonly args: readonly PositionalArg<any>[]
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

/** Runtime shape returned by the parser. Handlers that live in separate
 *  files (outside defineCommand) use this base type with index signatures. */
export interface ParsedCommand {
  readonly group: string
  readonly command: string
  readonly flags: Readonly<Record<string, string | boolean | number | undefined>>
  readonly args: Readonly<Record<string, string | undefined>>
  readonly raw: readonly string[]
}
