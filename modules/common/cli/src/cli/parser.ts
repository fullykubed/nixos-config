import { Effect } from "effect"
import type { CommandRegistry, ParsedCommand, Flag, Command } from "./types"
import type { CliError } from "./errors"
import {
  UnknownCommand,
  UnknownFlag,
  MissingArgument,
  InvalidValue,
  ParseError,
} from "./errors"

interface GlobalFlagsResult {
  readonly globalFlags: ReadonlyMap<string, string | boolean>
  readonly remaining: readonly string[]
}

interface ParsedArgs {
  readonly flags: ReadonlyMap<string, string | boolean>
  readonly args: readonly string[]
}

/**
 * Extract global flags from argv and return remaining args
 */
export const extractGlobalFlags = (
  globalFlags: readonly Flag[],
  argv: readonly string[]
): GlobalFlagsResult => {
  const flags = new Map<string, string | boolean>()
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
              flags.set(baseName, false)
              i++
              continue
            }
          }
          flags.set(flag.name, true)
          i++
        } else {
          // String flag
          const value = flagValue ?? argv[i + 1]
          if (value === undefined) {
            remaining.push(arg)
            i++
          } else {
            flags.set(flag.name, value)
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
            flags.set(flag.name, true)
            consumed = true
            i++
          } else {
            // String flag
            const value = argv[i + 1]
            if (value !== undefined && !value.startsWith("-")) {
              flags.set(flag.name, value)
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

  // Set defaults for boolean global flags
  for (const flag of globalFlags) {
    if (flag.kind === "boolean" && !flags.has(flag.name)) {
      flags.set(flag.name, flag.default)
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
  globalFlags: ReadonlyMap<string, string | boolean>
): Effect.Effect<ParsedArgs, CliError> =>
  Effect.gen(function* () {
    const flags = new Map<string, string | boolean>(globalFlags)
    const args: string[] = []

    const flagsByName = new Map<string, Flag>()
    const flagsByShort = new Map<string, Flag>()

    for (const flag of command.flags) {
      flagsByName.set(flag.name, flag)
      if (flag.short) {
        flagsByShort.set(flag.short, flag)
      }
      // Set defaults only if not already set by a global flag
      if (!flags.has(flag.name)) {
        if (flag.kind === "boolean") {
          flags.set(flag.name, flag.default)
        } else if (flag.default !== undefined) {
          flags.set(flag.name, flag.default)
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
          flags.set(actualFlagName, booleanValue ?? true)
          i++
        } else {
          // String flag
          const value = flagValue ?? argv[i + 1]
          if (value === undefined) {
            return yield* new ParseError({
              message: `Flag --${flag.name} requires a value`
            })
          }

          // Validate choices
          if (flag.choices && !flag.choices.includes(value)) {
            return yield* new InvalidValue({
              flag: flag.name,
              value,
              expected: `one of: ${flag.choices.join(", ")}`
            })
          }

          flags.set(flag.name, value)
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
            flags.set(flag.name, true)
            i++
          } else {
            // String flag
            const value = argv[i + 1]
            if (value === undefined || value.startsWith("-")) {
              return yield* new ParseError({
                message: `Flag -${flag.short ?? "?"} requires a value`
              })
            }

            // Validate choices
            if (flag.choices && !flag.choices.includes(value)) {
              return yield* new InvalidValue({
                flag: flag.name,
                value,
                expected: `one of: ${flag.choices.join(", ")}`
              })
            }

            flags.set(flag.name, value)
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
            flags.set(flag.name, true)
          }
          i++
        }
      } else {
        // Positional argument
        args.push(arg)
        i++
      }
    }

    // Skip validation when --help / -h is set — the user is asking for
    // usage info, not trying to run the command.
    const helpRequested = flags.get("help") === true

    if (!helpRequested) {
      // Validate required string flags
      for (const flag of command.flags) {
        if (flag.kind === "string" && flag.required && !flags.has(flag.name)) {
          return yield* new ParseError({
            message: `Required flag --${flag.name} not provided`
          })
        }
      }

      // Validate required positional arguments
      let requiredArgCount = 0
      for (const arg of command.args) {
        if (arg.required) {
          requiredArgCount++
        }
      }

      if (args.length < requiredArgCount) {
        const missingArg = command.args[args.length]
        if (missingArg) {
          return yield* new MissingArgument({
            name: missingArg.name,
            command: command.name
          })
        }
      }
    }

    return {
      flags,
      args,
    }
  })

/**
 * Create a help response for the top level (no group specified)
 */
const showTopLevelHelp = (): Effect.Effect<ParsedCommand> =>
  Effect.succeed({
    group: "",
    command: "help",
    flags: new Map(),
    args: [],
    raw: [],
  })

/**
 * Create a help response for a group (no command specified)
 */
const showGroupHelp = (
  groupName: string
): Effect.Effect<ParsedCommand> =>
  Effect.succeed({
    group: groupName,
    command: "help",
    flags: new Map(),
    args: [],
    raw: [],
  })

/**
 * Parse command line arguments into a structured command
 */
export const parse = <E>(
  registry: CommandRegistry<E>,
  argv: readonly string[]
): Effect.Effect<ParsedCommand, CliError> =>
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