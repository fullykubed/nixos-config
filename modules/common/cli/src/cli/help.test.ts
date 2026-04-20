import { describe, it, expect } from "bun:test"
import { topLevelHelp, groupHelp, commandHelp } from "./help"
import type { CommandRegistry, CommandGroup, Command, Flag } from "./types"
import { Effect } from "effect"

const makeCommand = (name: string, opts?: {
  flags?: Flag[]
  args?: Command["args"]
  description?: string
}): Command => ({
  name,
  description: opts?.description ?? `${name} command`,
  flags: opts?.flags ?? [],
  args: opts?.args ?? [],
  handler: () => Effect.void,
})

const makeGroup = (name: string, commands: Command[], description?: string): CommandGroup => ({
  name,
  description: description ?? `${name} group`,
  commands: new Map(commands.map(c => [c.name, c])),
})

describe("topLevelHelp", () => {
  it("includes group names and descriptions", () => {
    const registry: CommandRegistry = {
      globalFlags: [],
      groups: new Map([
        ["builders", { name: "builders", description: "Manage builders", commands: new Map() }],
      ]),
    }
    const help = topLevelHelp(registry)
    expect(help).toContain("builders")
    expect(help).toContain("Manage builders")
  })

  it("includes global flags", () => {
    const registry: CommandRegistry = {
      globalFlags: [
        { kind: "boolean", name: "json", short: "j", description: "Output JSON", default: false },
      ],
      groups: new Map(),
    }
    const help = topLevelHelp(registry)
    expect(help).toContain("--json")
    expect(help).toContain("-j")
    expect(help).toContain("Output JSON")
  })
})

describe("groupHelp", () => {
  it("lists commands with descriptions", () => {
    const group = makeGroup("builders", [
      makeCommand("list", { description: "List all builders" }),
      makeCommand("create", { description: "Create a builder" }),
    ])
    const help = groupHelp(group)
    expect(help).toContain("list")
    expect(help).toContain("List all builders")
    expect(help).toContain("create")
    expect(help).toContain("Create a builder")
  })
})

describe("commandHelp", () => {
  const group = makeGroup("builders", [])

  it("includes usage line with required args", () => {
    const cmd = makeCommand("create", {
      args: [{ name: "name", description: "Builder name", required: true }],
    })
    const help = commandHelp(group, cmd)
    expect(help).toContain("Usage: j builders create")
    expect(help).toContain("<name>")
  })

  it("shows optional args in brackets", () => {
    const cmd = makeCommand("ssh", {
      args: [{ name: "name", description: "Builder name", required: false }],
    })
    const help = commandHelp(group, cmd)
    expect(help).toContain("[name]")
  })

  it("formats variadic args", () => {
    const cmd = makeCommand("exec", {
      args: [
        { name: "cmd", description: "Command", required: true, variadic: true },
      ],
    })
    const help = commandHelp(group, cmd)
    expect(help).toContain("<cmd...>")
  })

  it("shows flag short forms", () => {
    const cmd = makeCommand("list", {
      flags: [
        { kind: "boolean", name: "verbose", short: "v", description: "Verbose", default: false },
      ],
    })
    const help = commandHelp(group, cmd)
    expect(help).toContain("-v, --verbose")
  })

  it("shows flag choices", () => {
    const cmd = makeCommand("create", {
      flags: [
        { kind: "string", name: "type", description: "Server type", required: false, choices: ["small", "big"] },
      ],
    })
    const help = commandHelp(group, cmd)
    expect(help).toContain("choices: small, big")
  })

  it("shows flag defaults", () => {
    const cmd = makeCommand("create", {
      flags: [
        { kind: "string", name: "format", description: "Output format", required: false, default: "table" },
      ],
    })
    const help = commandHelp(group, cmd)
    expect(help).toContain('default: "table"')
  })
})
