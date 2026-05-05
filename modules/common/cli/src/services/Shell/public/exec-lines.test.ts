import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { BunContext } from "@effect/platform-bun"
import { execLines } from "./exec-lines"

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
    return (exit.cause.error as { _tag?: string })._tag
  }
}

const TestExecutor = BunContext.layer

describe("execLines", () => {
  it("splits stdout into lines", async () => {
    const lines = await Effect.runPromise(
      execLines("printf", ["line1\\nline2\\nline3"]).pipe(Effect.provide(TestExecutor))
    )
    expect(lines).toEqual(["line1", "line2", "line3"])
  })

  it("returns empty array for empty output", async () => {
    const lines = await Effect.runPromise(
      execLines("true", []).pipe(Effect.provide(TestExecutor))
    )
    expect(lines).toEqual([])
  })

  it("handles single line without trailing newline", async () => {
    const lines = await Effect.runPromise(
      execLines("printf", ["single"]).pipe(Effect.provide(TestExecutor))
    )
    expect(lines).toEqual(["single"])
  })

  it("fails with ShellError when command cannot be spawned", async () => {
    const exit = await Effect.runPromiseExit(
      execLines("nonexistent-command-xyz", []).pipe(Effect.provide(TestExecutor))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("ShellError")
  })

  it("fails with ShellError when command does not exist", async () => {
    const exit = await Effect.runPromiseExit(
      execLines("nonexistent-command-xyz", []).pipe(Effect.provide(TestExecutor))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("ShellError")
  })

  it("includes the command string in ShellError", async () => {
    const exit = await Effect.runPromiseExit(
      execLines("nonexistent-command-xyz", ["arg1"]).pipe(Effect.provide(TestExecutor))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { command: string }
      expect(error.command).toBe("nonexistent-command-xyz arg1")
    }
  })
})
