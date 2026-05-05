import { Effect, Option } from "effect"
import type { CommandRegistry, Flag, IntegerFlag, StringFlag, Command, ParsedCommand } from "./types"
import { AbsolutePath } from "../lib/types/absolute-path"
import type {} from "./errors"
import {
  UnknownCommand,
  UnknownFlag,
  MissingArgument,
  InvalidValue,
  ValidationErrors,
  ParseError,
  ConflictingFlags,
} from "./errors"

/** Extract a human-readable message from a Brand validation error (which is an array of BrandErrors). */
const extractBrandError = (e: unknown): string => {
  if (Array.isArray(e)) return (e as { message?: string }[]).map((err) => err.message ?? "").filter(Boolean).join("; ")
  return String(e)
}

/**
 * Return the subset of flags from the first conflicting group (if any).
 * Returns undefined when all groups have at most one flag set.
 */
const findConflictingGroup = (
  groups: readonly (readonly string[])[] | undefined,
  setByUser: ReadonlySet<string>,
): Option.Option<readonly string[]> => {
  for (const group of groups ?? []) {
    const provided = group.filter((name) => setByUser.has(name))
    if (provided.length > 1) return Option.some(provided)
  }
  return Option.none()
}

/**
 * Resolve a raw CLI path string to an AbsolutePath.
 * Absolute paths pass through unchanged; relative paths are resolved against CWD.
 * Uses process.cwd() (a global) — no node:path import required.
 */
const resolvePath = (raw: string): AbsolutePath => {
  if (raw.startsWith("/")) return AbsolutePath(raw)
  const segments = `${process.cwd()}/${raw}`.split("/").filter(Boolean)
  const parts: string[] = []
  for (const seg of segments) {
    if (seg === "..") parts.pop()
    else if (seg !== ".") parts.push(seg)
  }
  return AbsolutePath(`/${parts.join("/")}`)
}

interface DeferredBrand {
  readonly target: "flag" | "arg"
  readonly name: string
  readonly value: string
  readonly brand: (raw: string) => unknown
}

/** Parse and validate a string as an integer flag value. Returns the coerced number or an InvalidValue error. */
const parseIntegerValue = (flag: IntegerFlag, raw: string) => {
  const parsed = Number(raw)
  if (Number.isNaN(parsed) || !Number.isInteger(parsed)) {
    return Effect.fail(new InvalidValue({ flag: flag.name, value: raw, expected: "an integer" }))
  }
  if (flag.min !== undefined && parsed < flag.min) {
    return Effect.fail(new InvalidValue({ flag: flag.name, value: raw, expected: `an integer >= ${String(flag.min)}` }))
  }
  return Effect.succeed(parsed)
}

interface GlobalFlagsResult {
  readonly globalFlags: Readonly<Record<string, string | boolean | number | undefined>>
  readonly remaining: readonly string[]
}


/**
 * Extract global flags from argv and return remaining args
 */
export const extractGlobalFlags = (
  globalFlags: readonly Flag[],
  argv: readonly string[]
): GlobalFlagsResult => {
  const flags: Record<string, string | boolean | number | undefined> = {}
  const remaining: string[] = []

  const globalFlagsByName = new Map<string, Flag>()
  const globalFlagsByShort = new Map<string, Flag>()

  for (const flag of globalFlags) {
    globalFlagsByName.set(flag.name, flag)
    if (flag.short) {
      globalFlagsByShort.set(flag.short, flag)
    }
  }

  let i = 0
  while (i < argv.length) {
    const arg = argv[i]!

    if (arg === "--") {
      // Stop processing flags, rest are positional
      remaining.push(...argv.slice(i))
      break
    }

    if (arg.startsWith("--")) {
      // Long flag
      const [flagName, flagValue] = arg.includes("=")
        ? arg.slice(2).split("=", 2) as [string, string]
        : [arg.slice(2), undefined] as [string, undefined]

      const flag = globalFlagsByName.get(flagName)
      if (flag) {
        if (flag.kind === "boolean") {
          if (flagName.startsWith("no-")) {
            // --no-verbose sets verbose to false
            const baseName = flagName.slice(3)
            const baseFlag = globalFlagsByName.get(baseName)
            if (baseFlag?.kind === "boolean") {
              flags[baseName] = false
              i++
              continue
            }
          }
          flags[flag.name] = true
          i++
        } else {
          // String or integer flag — both consume one value
          const value = flagValue ?? argv[i + 1]
          if (value === undefined) {
            remaining.push(arg)
            i++
          } else {
            flags[flag.name] = value
            i += flagValue !== undefined ? 1 : 2
          }
        }
      } else {
        remaining.push(arg)
        i++
      }
    } else if (arg.startsWith("-") && arg.length > 1 && arg !== "-") {
      // Short flag(s)
      const shortFlags = arg.slice(1)
      let consumed = false

      if (shortFlags.length === 1) {
        const flag = globalFlagsByShort.get(shortFlags)
        if (flag) {
          if (flag.kind === "boolean") {
            flags[flag.name] = true
            consumed = true
            i++
          } else {
            // String or integer flag
            const value = argv[i + 1]
            if (value !== undefined && !value.startsWith("-")) {
              flags[flag.name] = value
              consumed = true
              i += 2
            }
          }
        }
      }

      if (!consumed) {
        remaining.push(arg)
        i++
      }
    } else {
      remaining.push(arg)
      i++
    }
  }

  // Set defaults for global flags
  for (const flag of globalFlags) {
    if (!(flag.name in flags)) {
      if (flag.kind === "boolean") {
        flags[flag.name] = flag.default
      } else if (flag.default !== undefined) {
        flags[flag.name] = flag.default
      }
    }
  }

  return {
    globalFlags: flags,
    remaining,
  }
}

/**
 * Parse command-specific flags and positional arguments
 */
export const parseCommandArgs = <E>(
  command: Command<E>,
  argv: readonly string[],
  globalFlags: Readonly<Record<string, string | boolean | number | undefined>>
) =>
  Effect.gen(function* () {
    const flags: Record<string, string | boolean | number | undefined> = { ...globalFlags }
    const positionals: string[] = []
    const deferred: DeferredBrand[] = []
    /** Flags explicitly supplied by the user (not from defaults). Used for mutual exclusivity checks. */
    const setByUser = new Set<string>()

    const flagsByName = new Map<string, Flag>()
    const flagsByShort = new Map<string, Flag>()

    for (const flag of command.flags) {
      flagsByName.set(flag.name, flag)
      if (flag.short) {
        flagsByShort.set(flag.short, flag)
      }
      // Set defaults only if not already set by a global flag
      if (!(flag.name in flags)) {
        if (flag.kind === "boolean") {
          flags[flag.name] = flag.default
        } else if (flag.kind === "path" && flag.default !== undefined) {
          flags[flag.name] = resolvePath(flag.default)
        } else if (flag.default !== undefined) {
          // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment -- brand() return type is erased at runtime
          flags[flag.name] = "brand" in flag && flag.brand ? flag.brand(flag.default) : flag.default
        }
      }
    }

    let i = 0
    let stopFlagParsing = false

    while (i < argv.length) {
      const arg = argv[i]!

      if (arg === "--" && !stopFlagParsing) {
        stopFlagParsing = true
        i++
        continue
      }

      if (!stopFlagParsing && arg.startsWith("--")) {
        // Long flag
        const [flagName, flagValue] = arg.includes("=")
          ? arg.slice(2).split("=", 2) as [string, string]
          : [arg.slice(2), undefined] as [string, undefined]

        let flag = flagsByName.get(flagName)
        let actualFlagName = flagName
        let booleanValue: boolean | undefined = undefined

        // Handle --no- prefix for boolean flags
        if (!flag && flagName.startsWith("no-")) {
          const baseName = flagName.slice(3)
          flag = flagsByName.get(baseName)
          if (flag?.kind === "boolean") {
            actualFlagName = baseName
            booleanValue = false
          }
        }

        if (!flag) {
          return yield* new UnknownFlag({
            flag: flagName,
            command: command.name
          })
        }

        if (flag.kind === "boolean") {
          flags[actualFlagName] = booleanValue ?? true
          setByUser.add(actualFlagName)
          i++
        } else {
          // String, integer, or path flag
          const value = flagValue ?? argv[i + 1]
          if (value === undefined) {
            return yield* new ParseError({
              message: `Flag --${flag.name} requires a value`
            })
          }

          if (flag.kind === "integer") {
            flags[flag.name] = yield* parseIntegerValue(flag, value)
          } else if (flag.kind === "path") {
            flags[flag.name] = resolvePath(value)
          } else {
            const strFlag = flag as StringFlag
            // Validate choices
            if (strFlag.choices && !strFlag.choices.includes(value)) {
              return yield* new InvalidValue({
                flag: strFlag.name,
                value,
                expected: `one of: ${strFlag.choices.join(", ")}`
              })
            }
            if (strFlag.brand) {
              deferred.push({ target: "flag", name: strFlag.name, value, brand: strFlag.brand })
            }
            flags[strFlag.name] = value
          }
          setByUser.add(flag.name)
          i += flagValue !== undefined ? 1 : 2
        }
      } else if (!stopFlagParsing && arg.startsWith("-") && arg.length > 1 && arg !== "-") {
        // Short flag(s)
        const shortFlags = arg.slice(1)

        if (shortFlags.length === 1) {
          const flag = flagsByShort.get(shortFlags)
          if (!flag) {
            return yield* new UnknownFlag({
              flag: shortFlags,
              command: command.name
            })
          }

          if (flag.kind === "boolean") {
            flags[flag.name] = true
            setByUser.add(flag.name)
            i++
          } else {
            // String, integer, or path flag
            const value = argv[i + 1]
            if (value === undefined || value.startsWith("-")) {
              return yield* new ParseError({
                message: `Flag -${flag.short ?? "?"} requires a value`
              })
            }

            if (flag.kind === "integer") {
              flags[flag.name] = yield* parseIntegerValue(flag, value)
            } else if (flag.kind === "path") {
              flags[flag.name] = resolvePath(value)
            } else {
              const strFlag = flag as StringFlag
              // Validate choices
              if (strFlag.choices && !strFlag.choices.includes(value)) {
                return yield* new InvalidValue({
                  flag: strFlag.name,
                  value,
                  expected: `one of: ${strFlag.choices.join(", ")}`
                })
              }
              if (strFlag.brand) {
                deferred.push({ target: "flag", name: strFlag.name, value, brand: strFlag.brand })
              }
              flags[strFlag.name] = value
            }
            setByUser.add(flag.name)
            i += 2
          }
        } else {
          // Multiple short flags bundled together (only boolean flags supported)
          for (const shortFlag of shortFlags) {
            const flag = flagsByShort.get(shortFlag)
            if (!flag) {
              return yield* new UnknownFlag({
                flag: shortFlag,
                command: command.name
              })
            }
            if (flag.kind !== "boolean") {
              return yield* new ParseError({
                message: `Cannot bundle non-boolean flag -${shortFlag}`
              })
            }
            flags[flag.name] = true
            setByUser.add(flag.name)
          }
          i++
        }
      } else {
        // Positional argument
        positionals.push(arg)
        i++
      }
    }

    // Skip validation when --help / -h is set — the user is asking for
    // usage info, not trying to run the command.
    const helpRequested = flags.help === true

    if (!helpRequested) {
      // Validate required flags
      for (const flag of command.flags) {
        if (flag.kind !== "boolean" && flag.required && !(flag.name in flags)) {
          return yield* new ParseError({
            message: `Required flag --${flag.name} not provided`
          })
        }
      }

      // Validate mutually exclusive flag groups
      const conflictingGroup = findConflictingGroup(command.mutuallyExclusive, setByUser)
      if (Option.isSome(conflictingGroup)) {
        const commandName = command.name
        return yield* Effect.fail(new ConflictingFlags({ flags: conflictingGroup.value, command: commandName }))
      }

      // Validate required positional arguments
      let requiredArgCount = 0
      for (const arg of command.args) {
        if (arg.required) {
          requiredArgCount++
        }
      }

      if (positionals.length < requiredArgCount) {
        const missingArg = command.args[positionals.length]
        if (missingArg) {
          return yield* new MissingArgument({
            name: missingArg.name,
            command: command.name
          })
        }
      }
    }

    // Zip positionals with arg definitions to build named args object.
    // Brand constructors return subtypes of string, so the cast is safe.
    const args: Record<string, string | undefined> = {}
    for (let idx = 0; idx < command.args.length; idx++) {
      const argDef = command.args[idx]!
      const raw = positionals[idx]
      if (raw !== undefined && argDef.kind === "path") {
        args[argDef.name] = resolvePath(raw) as string
      } else {
        if (raw !== undefined && argDef.brand) {
          deferred.push({ target: "arg", name: argDef.name, value: raw, brand: argDef.brand })
        }
        args[argDef.name] = raw
      }
    }

    // Validate all deferred brands and collect errors
    const [brandErrors] = yield* Effect.partition(
      deferred,
      (d) => Effect.try({
        try: () => {
          const branded = d.brand(d.value) as string
          if (d.target === "flag") flags[d.name] = branded
          else args[d.name] = branded
          return branded
        },
        catch: (e) => new InvalidValue({ flag: d.name, value: d.value, expected: extractBrandError(e) })
      })
    )

    if (brandErrors.length === 1) return yield* Effect.fail(brandErrors[0]!)
    if (brandErrors.length > 1) return yield* Effect.fail(new ValidationErrors({ errors: brandErrors }))

    return {
      flags,
      args,
    }
  })

/**
 * Create a help response for the top level (no group specified)
 */
const showTopLevelHelp = () =>
  Effect.succeed<ParsedCommand>({
    group: "",
    command: "help",
    flags: {},
    args: {},
    raw: [],
  })

/**
 * Create a help response for a group (no command specified)
 */
const showGroupHelp = (
  groupName: string
) =>
  Effect.succeed<ParsedCommand>({
    group: groupName,
    command: "help",
    flags: {},
    args: {},
    raw: [],
  })

/**
 * Parse command line arguments into a structured command
 */
export const parse = <E>(
  registry: CommandRegistry<E>,
  argv: readonly string[]
) =>
  Effect.gen(function* () {
    // 1. Skip program name (argv[0] is bun, argv[1] is script path)
    const args = argv.slice(2)

    // Store raw args for reference
    const raw = [...args]

    // 2. Extract global flags (--json, --help, etc.)
    const { globalFlags, remaining } = extractGlobalFlags(registry.globalFlags, args)

    // 3. Match command group
    const groupName = remaining[0]
    if (!groupName) {
      return yield* showTopLevelHelp()
    }

    const group = registry.groups.get(groupName)
    if (!group) {
      return yield* new UnknownCommand({
        input: groupName,
        available: [...registry.groups.keys()]
      })
    }

    // 4. Match subcommand
    const commandName = remaining[1]
    if (!commandName) {
      return yield* showGroupHelp(groupName)
    }

    const command = group.commands.get(commandName)
    if (!command) {
      return yield* new UnknownCommand({
        input: commandName,
        available: [...group.commands.keys()]
      })
    }

    // 5. Parse command-specific flags and positional args
    const parsed = yield* parseCommandArgs(command, remaining.slice(2), globalFlags)

    return {
      group: groupName,
      command: commandName,
      flags: parsed.flags,
      args: parsed.args,
      raw,
    }
  })