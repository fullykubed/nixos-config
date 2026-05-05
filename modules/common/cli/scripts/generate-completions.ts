#!/usr/bin/env bun

import { registry } from "../src/cli/registry"
import type { Flag, PositionalArg, Command, CommandGroup } from "../src/cli/types"

const BUILDER_NAME_COMMANDS = new Set(["check", "destroy", "ssh"])
const BUILDER_NAME_COMPLETION = `"$sh(timeout 5 j builders list --json 2>/dev/null | jq -r '.[].name' 2>/dev/null)"`

function escapeYamlValue(s: string): string {
  return `"${s.replace(/"/g, '\\"')}"`
}

function flagKey(flag: Flag): string {
  const long = `--${flag.name}`
  if (flag.kind === "string" || flag.kind === "integer") {
    const base = `${long}=`
    return flag.short ? `-${flag.short}, ${base}` : base
  }
  // boolean flag
  return flag.short ? `-${flag.short}, ${long}` : long
}

function generatePersistentFlags(globalFlags: readonly Flag[]): string {
  const lines: string[] = []

  for (const flag of globalFlags) {
    const key = flagKey(flag)
    const description = escapeYamlValue(flag.description)
    lines.push(`  ${key}: ${description}`)
  }

  return lines.join('\n')
}

function generateCommandFlags(flags: readonly Flag[]): string[] {
  const lines: string[] = []

  for (const flag of flags) {
    const key = flagKey(flag)
    const description = escapeYamlValue(flag.description)
    lines.push(`          ${key}: ${description}`)
  }

  return lines
}

function generateFlagCompletions(flags: readonly Flag[]): string[] {
  const lines: string[] = []

  for (const flag of flags) {
    if (flag.kind === "string" && flag.choices) {
      lines.push(`          flag:`)
      lines.push(`            ${flag.name}:`)
      for (const choice of flag.choices) {
        lines.push(`              - ${escapeYamlValue(choice)}`)
      }
    }
  }

  return lines
}

function needsBuilderNameCompletion(command: Command, groupName: string): boolean {
  return (
    groupName === "builders" &&
    BUILDER_NAME_COMMANDS.has(command.name) &&
    command.args.some(arg => arg.name === "name")
  )
}

function generateCommand(command: Command, groupName: string, indent: string): string[] {
  const lines: string[] = []

  lines.push(`${indent}- name: ${command.name}`)
  lines.push(`${indent}  description: ${escapeYamlValue(command.description)}`)

  // Generate flags
  if (command.flags.length > 0) {
    lines.push(`${indent}  flags:`)
    lines.push(...generateCommandFlags(command.flags))
  }

  // Generate completion section
  const flagCompletions = generateFlagCompletions(command.flags)
  const needsPositionalCompletion = needsBuilderNameCompletion(command, groupName)

  if (flagCompletions.length > 0 || needsPositionalCompletion) {
    lines.push(`${indent}  completion:`)

    if (flagCompletions.length > 0) {
      lines.push(...flagCompletions)
    }

    if (needsPositionalCompletion) {
      lines.push(`${indent}    positional:`)
      lines.push(`${indent}      - [${BUILDER_NAME_COMPLETION}]`)
    }
  }

  return lines
}

function generateGroup(group: CommandGroup, indent: string): string[] {
  const lines: string[] = []

  lines.push(`${indent}- name: ${group.name}`)
  lines.push(`${indent}  description: ${escapeYamlValue(group.description)}`)

  if (group.commands.size > 0) {
    lines.push(`${indent}  commands:`)

    // Sort commands by name for deterministic output
    const sortedCommands = Array.from(group.commands.entries()).sort(([a], [b]) => a.localeCompare(b))

    for (const [_, command] of sortedCommands) {
      lines.push(...generateCommand(command, group.name, indent + "    "))
    }
  }

  return lines
}

function generateYaml(): string {
  const lines: string[] = []

  // Header
  lines.push("# yaml-language-server: $schema=https://carapace.sh/schemas/command.json")
  lines.push("name: j")
  lines.push("description: \"Jack's CLI toolset\"")

  // Persistent flags (global flags)
  if (registry.globalFlags.length > 0) {
    lines.push("persistentflags:")
    lines.push(generatePersistentFlags(registry.globalFlags))
  }

  // Commands (groups)
  if (registry.groups.size > 0) {
    lines.push("commands:")

    // Sort groups by name for deterministic output
    const sortedGroups = Array.from(registry.groups.entries()).sort(([a], [b]) => a.localeCompare(b))

    for (const [_, group] of sortedGroups) {
      lines.push(...generateGroup(group, "  "))
    }
  }

  return lines.join('\n')
}

// Generate and output the YAML
console.log(generateYaml())