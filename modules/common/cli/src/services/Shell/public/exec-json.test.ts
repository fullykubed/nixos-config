import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { BunContext } from "@effect/platform-bun"
import { execJson } from "./exec-json"

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
    return (exit.cause.error as { _tag?: string })._tag
  }
}

const TestExecutor = BunContext.layer

describe("execJson", () => {
  it("parses valid JSON output", async () => {
    const result = await Effect.runPromise(
      execJson<{ key: string }>("echo", ['{"key":"value"}']).pipe(Effect.provide(TestExecutor))
    )
    expect(result).toEqual({ key: "value" })
  })

  it("parses JSON array output", async () => {
    const result = await Effect.runPromise(
      execJson<number[]>("echo", ["[1,2,3]"]).pipe(Effect.provide(TestExecutor))
    )
    expect(result).toEqual([1, 2, 3])
  })

  it("parses nested JSON", async () => {
    const result = await Effect.runPromise(
      execJson<{ a: { b: number } }>("echo", ['{"a":{"b":42}}']).pipe(Effect.provide(TestExecutor))
    )
    expect(result).toEqual({ a: { b: 42 } })
  })

  it("fails with JsonParseError for invalid JSON", async () => {
    const exit = await Effect.runPromiseExit(
      execJson("echo", ["not-json"]).pipe(Effect.provide(TestExecutor))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("JsonParseError")
  })

  it("JsonParseError includes the raw output", async () => {
    const exit = await Effect.runPromiseExit(
      execJson("echo", ["bad{json"]).pipe(Effect.provide(TestExecutor))
    )
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { raw: string; command: string }
      expect(error.raw).toContain("bad{json")
      expect(error.command).toBe("echo bad{json")
    }
  })

  it("fails with ShellError when command cannot be spawned", async () => {
    const exit = await Effect.runPromiseExit(
      execJson("nonexistent-command-xyz", []).pipe(Effect.provide(TestExecutor))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("ShellError")
  })

  it("fails with ShellError when command does not exist", async () => {
    const exit = await Effect.runPromiseExit(
      execJson("nonexistent-command-xyz", []).pipe(Effect.provide(TestExecutor))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("ShellError")
  })

  it("handles empty JSON object", async () => {
    const result = await Effect.runPromise(
      execJson<Record<string, never>>("echo", ["{}"]).pipe(Effect.provide(TestExecutor))
    )
    expect(result).toEqual({})
  })
})
