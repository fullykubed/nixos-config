import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { extractGlobalFlags, parseCommandArgs, parse } from "./parser"
import type { Command, CommandRegistry, Flag } from "./types"
import { BranchName } from "../services/Git/types"

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

const intFlag = (name: string, opts?: { short?: string; required?: boolean; default?: number; min?: number }): Flag => ({
  kind: "integer",
  name,
  short: opts?.short,
  description: `${name} flag`,
  required: opts?.required ?? false,
  default: opts?.default,
  min: opts?.min,
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
    expect(result.globalFlags.json).toBe(true)
    expect(result.remaining).toEqual(["builders", "list"])
  })

  it("extracts string global flags", () => {
    const flags = [strFlag("format", { short: "f" })]
    const result = extractGlobalFlags(flags, ["--format", "table", "builders", "list"])
    expect(result.globalFlags.format).toBe("table")
    expect(result.remaining).toEqual(["builders", "list"])
  })

  it("stops parsing at --", () => {
    const flags = [boolFlag("json")]
    const result = extractGlobalFlags(flags, ["--", "--json", "builders"])
    expect(result.globalFlags.json).toBe(false) // default
    expect(result.remaining).toEqual(["--", "--json", "builders"])
  })

  it("handles short flags", () => {
    const flags = [boolFlag("json", { short: "j" })]
    const result = extractGlobalFlags(flags, ["-j", "builders"])
    expect(result.globalFlags.json).toBe(true)
    expect(result.remaining).toEqual(["builders"])
  })

  it("sets defaults for boolean flags not present", () => {
    const flags = [boolFlag("json"), boolFlag("verbose", { default: true })]
    const result = extractGlobalFlags(flags, ["builders"])
    expect(result.globalFlags.json).toBe(false)
    expect(result.globalFlags.verbose).toBe(true)
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
        {}
      )
    )
    expect(r.flags.verbose).toBe(true)
  })

  it("parses long string flags", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", { flags: [strFlag("name")] }),
        ["--name", "foo"],
        {}
      )
    )
    expect(r.flags.name).toBe("foo")
  })

  it("parses short flags", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", { flags: [boolFlag("verbose", { short: "v" })] }),
        ["-v"],
        {}
      )
    )
    expect(r.flags.verbose).toBe(true)
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
        {}
      )
    )
    expect(r.flags.verbose).toBe(true)
    expect(r.flags.force).toBe(true)
  })

  it("handles --no- prefix for boolean flags", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", { flags: [boolFlag("verify", { default: true })] }),
        ["--no-verify"],
        {}
      )
    )
    expect(r.flags.verify).toBe(false)
  })

  it("validates flag choices", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(
        makeCommand("test", { flags: [strFlag("type", { choices: ["a", "b"] })] }),
        ["--type", "c"],
        {}
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
  })

  it("accepts valid choices", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", { flags: [strFlag("type", { choices: ["a", "b"] })] }),
        ["--type", "a"],
        {}
      )
    )
    expect(r.flags.type).toBe("a")
  })

  it("fails on unknown flags", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(makeCommand("test"), ["--unknown"], {})
    )
    expect(Exit.isFailure(exit)).toBe(true)
  })

  it("fails on required string flag not provided", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(
        makeCommand("test", { flags: [strFlag("name", { required: true })] }),
        [],
        {}
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
  })

  it("parses integer flag from --project 42", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", { flags: [intFlag("project", { short: "p" })] }),
        ["--project", "42"],
        {}
      )
    )
    expect(r.flags.project).toBe(42)
  })

  it("parses integer flag from --project=42", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", { flags: [intFlag("project")] }),
        ["--project=42"],
        {}
      )
    )
    expect(r.flags.project).toBe(42)
  })

  it("parses integer flag from short -p 42", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", { flags: [intFlag("project", { short: "p" })] }),
        ["-p", "42"],
        {}
      )
    )
    expect(r.flags.project).toBe(42)
  })

  it("rejects non-numeric value for integer flag", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(
        makeCommand("test", { flags: [intFlag("project")] }),
        ["--project", "abc"],
        {}
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("InvalidValue")
    }
  })

  it("rejects float value for integer flag", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(
        makeCommand("test", { flags: [intFlag("project")] }),
        ["--project", "3.14"],
        {}
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("InvalidValue")
    }
  })

  it("respects min constraint on integer flag", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(
        makeCommand("test", { flags: [intFlag("project", { min: 1 })] }),
        ["--project", "0"],
        {}
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("InvalidValue")
      if (exit.cause.error._tag === "InvalidValue") {
        expect(exit.cause.error.expected).toContain(">= 1")
      }
    }
  })

  it("sets default for integer flag when not provided", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", { flags: [intFlag("project", { default: 10 })] }),
        [],
        {}
      )
    )
    expect(r.flags.project).toBe(10)
  })

  it("fails when required integer flag is not provided", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(
        makeCommand("test", { flags: [intFlag("project", { required: true })] }),
        [],
        {}
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
  })

  it("applies brand function to positional args", async () => {
    const upper = (s: string) => s.toUpperCase()
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", {
          args: [{ name: "branch", description: "branch", required: true, brand: upper }],
        }),
        ["my-branch"],
        {}
      )
    )
    expect(r.args.branch).toBe("MY-BRANCH")
  })

  it("does not apply brand when positional arg is missing (optional)", async () => {
    const upper = (s: string) => s.toUpperCase()
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", {
          args: [{ name: "branch", description: "branch", required: false, brand: upper }],
        }),
        [],
        {}
      )
    )
    expect(r.args.branch).toBeUndefined()
  })

  it("applies brand function to string flags", async () => {
    const upper = (s: string) => s.toUpperCase()
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", {
          flags: [{ kind: "string", name: "into", description: "target", required: false, brand: upper } as Flag],
        }),
        ["--into", "develop"],
        {}
      )
    )
    expect(r.flags.into).toBe("DEVELOP")
  })

  it("applies brand to string flag default value", async () => {
    const upper = (s: string) => s.toUpperCase()
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", {
          flags: [{ kind: "string", name: "into", description: "target", required: false, default: "main", brand: upper } as Flag],
        }),
        [],
        {}
      )
    )
    expect(r.flags.into).toBe("MAIN")
  })

  it("applies brand to short string flag", async () => {
    const upper = (s: string) => s.toUpperCase()
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", {
          flags: [{ kind: "string", name: "into", short: "i", description: "target", required: false, brand: upper } as Flag],
        }),
        ["-i", "develop"],
        {}
      )
    )
    expect(r.flags.into).toBe("DEVELOP")
  })

  it("rejects invalid branded positional arg", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(
        makeCommand("test", {
          args: [{ name: "branch", description: "branch", required: true, brand: BranchName }],
        }),
        ["invalid..branch"],
        {}
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("InvalidValue")
    }
  })

  it("rejects invalid branded long flag", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(
        makeCommand("test", {
          flags: [{ kind: "string", name: "into", description: "target", required: false, brand: BranchName } as Flag],
        }),
        ["--into", "invalid..branch"],
        {}
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("InvalidValue")
    }
  })

  it("rejects invalid branded short flag", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(
        makeCommand("test", {
          flags: [{ kind: "string", name: "into", short: "i", description: "target", required: false, brand: BranchName } as Flag],
        }),
        ["-i", "invalid..branch"],
        {}
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("InvalidValue")
    }
  })

  it("resolves absolute path arg unchanged", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", {
          args: [{ name: "dir", description: "directory", required: true, kind: "path" }],
        }),
        ["/tmp/foo"],
        {}
      )
    )
    expect(r.args.dir).toBe("/tmp/foo")
  })

  it("resolves relative path arg from CWD", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", {
          args: [{ name: "dir", description: "directory", required: true, kind: "path" }],
        }),
        ["foo/bar"],
        {}
      )
    )
    expect(typeof r.args.dir).toBe("string")
    expect((r.args.dir!).startsWith("/")).toBe(true)
    expect(r.args.dir!).toBe(`${process.cwd()}/foo/bar`)
  })

  it("resolves . path arg to CWD", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", {
          args: [{ name: "dir", description: "directory", required: false, kind: "path" }],
        }),
        ["."],
        {}
      )
    )
    expect(r.args.dir!).toBe(process.cwd())
  })

  it("leaves optional path arg undefined when not provided", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommand("test", {
          args: [{ name: "dir", description: "directory", required: false, kind: "path" }],
        }),
        [],
        {}
      )
    )
    expect(r.args.dir).toBeUndefined()
  })
})

// ── mutually exclusive flags ─────────────────────────────────────────

const makeCommandWithExclusive = (groups: (readonly string[])[], flags: Flag[]) => ({
  name: "test",
  description: "test command",
  flags,
  args: [] as Command["args"],
  mutuallyExclusive: groups,
  handler: () => Effect.void,
}) satisfies Command

describe("mutually exclusive flags", () => {
  it("allows a single flag from an exclusive group", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommandWithExclusive(
          [["json", "yaml"]],
          [boolFlag("json"), boolFlag("yaml")]
        ),
        ["--json"],
        {}
      )
    )
    expect(r.flags.json).toBe(true)
    expect(r.flags.yaml).toBe(false)
  })

  it("allows no flags from an exclusive group", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommandWithExclusive(
          [["json", "yaml"]],
          [boolFlag("json"), boolFlag("yaml")]
        ),
        [],
        {}
      )
    )
    expect(r.flags.json).toBe(false)
    expect(r.flags.yaml).toBe(false)
  })

  it("fails when two flags from the same exclusive group are provided", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(
        makeCommandWithExclusive(
          [["json", "yaml"]],
          [boolFlag("json"), boolFlag("yaml")]
        ),
        ["--json", "--yaml"],
        {}
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("ConflictingFlags")
    }
  })

  it("error includes the names of the conflicting flags", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(
        makeCommandWithExclusive(
          [["json", "yaml", "text"]],
          [boolFlag("json"), boolFlag("yaml"), boolFlag("text")]
        ),
        ["--json", "--text"],
        {}
      )
    )
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const err = exit.cause.error as { _tag: string; flags: readonly string[] }
      expect(err._tag).toBe("ConflictingFlags")
      expect(err.flags).toContain("json")
      expect(err.flags).toContain("text")
      expect(err.flags).not.toContain("yaml")
    }
  })

  it("independent exclusive groups are checked separately", async () => {
    // group A: json/yaml, group B: verbose/quiet — providing one from each is fine
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommandWithExclusive(
          [["json", "yaml"], ["verbose", "quiet"]],
          [boolFlag("json"), boolFlag("yaml"), boolFlag("verbose"), boolFlag("quiet")]
        ),
        ["--json", "--verbose"],
        {}
      )
    )
    expect(r.flags.json).toBe(true)
    expect(r.flags.verbose).toBe(true)
  })

  it("fails when two flags from the second group conflict", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(
        makeCommandWithExclusive(
          [["json", "yaml"], ["verbose", "quiet"]],
          [boolFlag("json"), boolFlag("yaml"), boolFlag("verbose"), boolFlag("quiet")]
        ),
        ["--json", "--verbose", "--quiet"],
        {}
      )
    )
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const err = exit.cause.error as { _tag: string; flags: readonly string[] }
      expect(err._tag).toBe("ConflictingFlags")
      expect(err.flags).toContain("verbose")
      expect(err.flags).toContain("quiet")
    }
  })

  it("defaults do not count as user-provided (no false conflict)", async () => {
    // json defaults to false but is still in the group — should not conflict with yaml being set
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommandWithExclusive(
          [["json", "yaml"]],
          [boolFlag("json"), boolFlag("yaml")]
        ),
        ["--yaml"],
        {}
      )
    )
    expect(r.flags.yaml).toBe(true)
    expect(r.flags.json).toBe(false)
  })

  it("bypasses exclusivity check when --help is set", async () => {
    const r = await Effect.runPromise(
      parseCommandArgs(
        makeCommandWithExclusive(
          [["json", "yaml"]],
          [boolFlag("help"), boolFlag("json"), boolFlag("yaml")]
        ),
        ["--help", "--json", "--yaml"],
        {}
      )
    )
    expect(r.flags.help).toBe(true)
  })

  it("works with string flags — only explicitly provided ones conflict", async () => {
    const exit = await Effect.runPromiseExit(
      parseCommandArgs(
        makeCommandWithExclusive(
          [["output", "format"]],
          [
            strFlag("output", { required: false }),
            strFlag("format", { required: false }),
          ]
        ),
        ["--output", "json", "--format", "yaml"],
        {}
      )
    )
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const err = exit.cause.error as { _tag: string; flags: readonly string[] }
      expect(err._tag).toBe("ConflictingFlags")
    }
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
    expect(r.flags.help).toBe(true)
  })
})
