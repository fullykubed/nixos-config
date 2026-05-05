import type { CommandRegistry, CommandGroup, Command, Flag } from "./types"

/**
 * Generate top-level help text showing all command groups
 */
export function topLevelHelp<E>(registry: CommandRegistry<E>): string {
  const lines: string[] = []

  lines.push("j - Desktop CLI")
  lines.push("")
  lines.push("Usage: j <command-group> <command> [flags] [args]")
  lines.push("")

  if (registry.groups.size > 0) {
    lines.push("Command Groups:")

    // Calculate max width for alignment
    const maxGroupWidth = Math.max(
      ...Array.from(registry.groups.keys()).map(name => name.length)
    )

    for (const [name, group] of registry.groups) {
      lines.push(`  ${name.padEnd(maxGroupWidth)}  ${group.description}`)
    }
    lines.push("")
  }

  if (registry.globalFlags.length > 0) {
    lines.push("Global Flags:")
    lines.push(...formatFlags(registry.globalFlags))
  }

  return lines.join("\n")
}

/**
 * Generate help text for a specific command group
 */
export function groupHelp<E>(group: CommandGroup<E>): string {
  const lines: string[] = []

  lines.push(`j ${group.name} - ${group.description}`)
  lines.push("")
  lines.push(`Usage: j ${group.name} <command> [flags] [args]`)
  lines.push("")

  if (group.commands.size > 0) {
    lines.push("Commands:")

    // Calculate max width for alignment
    const maxCommandWidth = Math.max(
      ...Array.from(group.commands.keys()).map(name => name.length)
    )

    for (const [name, command] of group.commands) {
      lines.push(`  ${name.padEnd(maxCommandWidth)}  ${command.description}`)
    }
  }

  return lines.join("\n")
}

/**
 * Generate help text for a specific command
 */
export function commandHelp<E>(group: CommandGroup<E>, command: Command<E>): string {
  const lines: string[] = []

  lines.push(`j ${group.name} ${command.name} - ${command.description}`)
  lines.push("")

  // Build usage pattern
  let usage = `Usage: j ${group.name} ${command.name}`

  if (command.flags.length > 0) {
    usage += " [flags]"
  }

  if (command.args.length > 0) {
    for (const arg of command.args) {
      if (arg.required) {
        if (arg.variadic) {
          usage += ` <${arg.name}...>`
        } else {
          usage += ` <${arg.name}>`
        }
      } else {
        if (arg.variadic) {
          usage += ` [${arg.name}...]`
        } else {
          usage += ` [${arg.name}]`
        }
      }
    }
  }

  lines.push(usage)
  lines.push("")

  // Show positional arguments if any
  if (command.args.length > 0) {
    lines.push("Arguments:")
    const maxArgWidth = Math.max(...command.args.map(arg => {
      let name = arg.name
      if (arg.variadic) name += "..."
      return name.length
    }))

    for (const arg of command.args) {
      let name = arg.name
      if (arg.variadic) name += "..."
      const marker = arg.required ? "<required>" : "[optional]"
      lines.push(`  ${name.padEnd(maxArgWidth)}  ${arg.description} ${marker}`)
    }
    lines.push("")
  }

  // Show flags if any
  if (command.flags.length > 0) {
    lines.push("Flags:")
    lines.push(...formatFlags(command.flags))
  }

  // Show mutually exclusive groups if any
  if (command.mutuallyExclusive && command.mutuallyExclusive.length > 0) {
    lines.push("")
    lines.push("Mutually Exclusive:")
    for (const group of command.mutuallyExclusive) {
      lines.push(`  ${group.map((n) => `--${n}`).join(", ")}  (use at most one)`)
    }
  }

  return lines.join("\n")
}

/**
 * Helper function to format flags with consistent alignment
 */
function formatFlags(flags: readonly Flag[]): string[] {
  if (flags.length === 0) return []

  const lines: string[] = []

  // Calculate max width for flag names (including short forms)
  const maxFlagWidth = Math.max(...flags.map(flag => {
    let flagText = `--${flag.name}`
    if (flag.short) {
      flagText = `-${flag.short}, ${flagText}`
    }
    return flagText.length
  }))

  for (const flag of flags) {
    let flagText = `--${flag.name}`
    if (flag.short) {
      flagText = `-${flag.short}, ${flagText}`
    }

    let description = flag.description

    // Add type and default information
    if (flag.kind === "string") {
      if (flag.choices) {
        description += ` (choices: ${flag.choices.join(", ")})`
      }
      if (flag.default !== undefined) {
        description += ` (default: "${flag.default}")`
      }
      if (flag.required) {
        description += " <required>"
      }
    } else if (flag.kind === "path") {
      description += " <path>"
      if (flag.default !== undefined) {
        description += ` (default: "${flag.default}")`
      }
      if (flag.required) {
        description += " <required>"
      }
    } else if (flag.kind === "integer") {
      if (flag.default !== undefined) {
        description += ` (default: ${String(flag.default)})`
      }
      if (flag.required) {
        description += " <required>"
      }
    } else if (flag.default) {
      description += " (default: true)"
    }

    lines.push(`  ${flagText.padEnd(maxFlagWidth)}  ${description}`)
  }

  return lines
}