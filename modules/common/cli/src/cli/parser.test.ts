import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { extractGlobalFlags, parseCommandArgs, parse } from "./parser"
import type { Command, CommandRegistry, Flag } from "./types"

// ── Test helpers ──────────────────────────────────────────────────────

const boolFlag = (name: string, opts?: { short?: string; default?: boolean }): Flag => ({
  kind: "boolean",
  name,
  short: opts?.short,
  description: `${name} flag`,
  default: opts?.default ?? false,
})

const strFlag = (name: string, opts?: { short?: string; required?: boolean; choices?: string[]; default?: string }): Flag => ({
  kind: "string",
  name,
  short: opts?.short,
  description: `${name} flag`,
  required: opts?.required ?? false,
  choices: opts?.choices,
  default: opts?.default,
})

const makeCommand = (name: string, opts?: { flags?: Flag[]; args?: Command["args"] }): Command => ({
  name,
  description: `${name} command`,
  flags: opts?.flags ?? [],
  args: opts?.args ?? [],
  handler: () => Effect.void,
})

const makeRegistry = (groups: Record<string, Record<string, Command>>, globalFlags: Flag[] = []): CommandRegistry => ({
  globalFlags,
  groups: new Map(
    Object.entries(groups).map(([gName, cmds]) => [
      gName,
      {
        name: gName,
        description: `${gName} group`,
        commands: new Map(Object.entries(cmds)),
      },
    ])
  ),
})

// ── extractGlobalFlags ──────────────────────────────────────────────

describe("extractGlobalFlags", () => {
  it("extracts boolean global flags", () => {
    const flags = [boolFlag("json", { short: "j" }), boolFlag("verbose", { short: "v" })]
    const result = extractGlobalFlags(flags, ["--json", "builders", "list"])
    expect(result.globalFlags.get("json")).toBe(true)
    expect(result.remaining).toEqual(["builders", "list"])
  })

  it("extracts string global flags", () => {
    const flags = [strFlag("format", { short: "f" })]
    const result = extractGlobalFlags(flags, ["--format", "table", "builders", "list"])
    expect(result.globalFlags.get("format")).toBe("table")
    expect(result.remaining).toEqual(["builders", "list"])
  })

  it("stops parsing at --", () => {
    const flags = [boolFlag("json")]
    const result = extractGlobalFlags(flags, ["--", "--json", "builders"])
    expect(result.globalFlags.get("json")).toBe(false) // default
    expect(result.remaining).toEqual(["--", "--json", "builders"])
  })

  it("handles short flags", () => {
    const flags = [boolFlag("json", { short: "j" })]
    const result = extractGlobalFlags(flags, ["-j", "builders"])
    expect(result.globalFlags.get("json")).toBe(true)
    expect(result.remaining).toEqual(["builders"])
  })

  it("sets defaults for boolean flags not present", () => {
    const flags = [boolFlag("json"), boolFlag("verbose", { default: true })]
    const result = extractGlobalFlags(flags, ["builders"])
    expect(result.globalFlags.get("json")).toBe(false)
    expect(result.globalFlags.get("verbose")).toBe(true)
  })

  it("passes through unknown flags as remaining", () => {
    const flags = [boolFlag("json")]
    const result = extractGlobalFlags(flags, ["--unknown", "builders"])
    expect(result.remaining).toEqual(["--unknown", "builders"])
  })
})

// ── parseCommandArgs ────────────────────────────────────────────────

describe("parseCommandArgs", () => {
  it("parses long boolean flags", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", { flags: [boolFlag("verbose")] }),
        ["--verbose"],
        new Map()
      )
    )
    expect(r.flags.get("verbose")).toBe(true)
  })

  it("parses long string flags", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", { flags: [strFlag("name")] }),
        ["--name", "foo"],
        new Map()
      )
    )
    expect(r.flags.get("name")).toBe("foo")
  })

  it("parses short flags", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", { flags: [boolFlag("verbose", { short: "v" })] }),
        ["-v"],
        new Map()
      )
    )
    expect(r.flags.get("verbose")).toBe(true)
  })

  it("parses bundled boolean short flags", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", {
          flags: [
            boolFlag("verbose", { short: "v" }),
            boolFlag("force", { short: "f" }),
          ],
        }),
        ["-vf"],
        new Map()
      )
    )
    expect(r.flags.get("verbose")).toBe(true)
    expect(r.flags.get("force")).toBe(true)
  })

  it("handles --no- prefix for boolean flags", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", { flags: [boolFlag("verify", { default: true })] }),
        ["--no-verify"],
        new Map()
      )
    )
    expect(r.flags.get("verify")).toBe(false)
  })

  it("validates flag choices", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(
        makeCommand("test", { flags: [strFlag("type", { choices: ["a", "b"] })] }),
        ["--type", "c"],
        new Map()
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
  })

  it("accepts valid choices", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", { flags: [strFlag("type", { choices: ["a", "b"] })] }),
        ["--type", "a"],
        new Map()
      )
    )
    expect(r.flags.get("type")).toBe("a")
  })

  it("fails on unknown flags", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(makeCommand("test"), ["--unknown"], new Map())
    )
    expect(Exit.isFailure(exit)).toBe(true)
  })

  it("fails on required string flag not provided", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(
        makeCommand("test", { flags: [strFlag("name", { required: true })] }),
        [],
        new Map()
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
  })
})

// ── parse ───────────────────────────────────────────────────────────

describe("parse", () => {
  const registry = makeRegistry(
    {
      builders: {
        list: makeCommand("list"),
        create: makeCommand("create", {
          args: [{ name: "name", description: "builder name", required: true }],
        }),
      },
    },
    [boolFlag("json", { short: "j" }), boolFlag("help", { short: "h" })]
  )

  it("resolves group and subcommand", async () => {
    const r = await Effect.runPromise(parse(registry, ["node", "script", "builders", "list"]))
    expect(r.group).toBe("builders")
    expect(r.command).toBe("list")
  })

  it("returns top-level help when no args", async () => {
    const r = await Effect.runPromise(parse(registry, ["node", "script"]))
    expect(r.command).toBe("help")
    expect(r.group).toBe("")
  })

  it("returns group help when no subcommand", async () => {
    const r = await Effect.runPromise(parse(registry, ["node", "script", "builders"]))
    expect(r.command).toBe("help")
    expect(r.group).toBe("builders")
  })

  it("fails on unknown group", async () => {
    const exit = await Effect.runPromiseExit(
      parse(registry, ["node", "script", "unknown"])
    )
    expect(Exit.isFailure(exit)).toBe(true)
  })

  it("fails on unknown subcommand", async () => {
    const exit = await Effect.runPromiseExit(
      parse(registry, ["node", "script", "builders", "unknown"])
    )
    expect(Exit.isFailure(exit)).toBe(true)
  })

  it("fails on missing required arg", async () => {
    const exit = await Effect.runPromiseExit(
      parse(registry, ["node", "script", "builders", "create"])
    )
    expect(Exit.isFailure(exit)).toBe(true)
  })

  it("--help bypasses validation on required args", async () => {
    const r = await Effect.runPromise(parse(registry, ["node", "script", "--help", "builders", "create"]))
    expect(r.flags.get("help")).toBe(true)
  })
})
