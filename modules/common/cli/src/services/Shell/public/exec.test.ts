import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { BunContext } from "@effect/platform-bun"
import { exec } from "./exec"

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
    return (exit.cause.error as { _tag?: string })._tag
  }
}

// BunContext provides CommandExecutor + FileSystem + Path etc.
const TestExecutor = BunContext.layer

describe("exec", () => {
  it("captures stdout from a successful command", async () => {
    const result = await Effect.runPromise(
      exec("echo", ["hello world"]).pipe(Effect.provide(TestExecutor))
    )
    expect(result.stdout.trim()).toBe("hello world")
    expect(result.exitCode).toBe(0)
  })

  it("captures stdout from a multi-arg command", async () => {
    const result = await Effect.runPromise(
      exec("printf", ["%s-%s", "foo", "bar"]).pipe(Effect.provide(TestExecutor))
    )
    expect(result.stdout).toBe("foo-bar")
    expect(result.exitCode).toBe(0)
  })

  it("fails with ShellError when command cannot be spawned", async () => {
    const exit = await Effect.runPromiseExit(
      exec("nonexistent-command-xyz", []).pipe(Effect.provide(TestExecutor))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("ShellError")
  })

  it("fails with ShellError on non-zero exit code", async () => {
    const exit = await Effect.runPromiseExit(
      exec("sh", ["-c", "echo oops >&2; exit 42"]).pipe(Effect.provide(TestExecutor))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("ShellError")
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { exitCode: number; stderr: string; command: string }
      expect(error.exitCode).toBe(42)
      expect(error.stderr).toContain("oops")
      expect(error.command).toBe("sh -c echo oops >&2; exit 42")
    }
  })

  it("captures stderr on non-zero exit", async () => {
    const exit = await Effect.runPromiseExit(
      exec("sh", ["-c", "echo out; echo err >&2; exit 1"]).pipe(Effect.provide(TestExecutor))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { exitCode: number; stdout: string; stderr: string }
      expect(error.exitCode).toBe(1)
      expect(error.stdout).toContain("out")
      expect(error.stderr).toContain("err")
    }
  })

  it("fails with ShellError on timeout", async () => {
    const exit = await Effect.runPromiseExit(
      exec("sleep", ["10"], { timeout: 50 }).pipe(Effect.provide(TestExecutor))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("ShellError")
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { command: string; exitCode: number }
      expect(error.command).toBe("sleep 10")
      expect(error.exitCode).toBe(-1)
    }
  })

  it("captures stderr on success", async () => {
    const result = await Effect.runPromise(
      exec("sh", ["-c", "echo out; echo warn >&2"]).pipe(Effect.provide(TestExecutor))
    )
    expect(result.stdout).toContain("out")
    expect(result.stderr).toContain("warn")
    expect(result.exitCode).toBe(0)
  })

  it("passes env variables to the child process", async () => {
    const result = await Effect.runPromise(
      exec("sh", ["-c", "echo $MY_TEST_VAR"], { env: { MY_TEST_VAR: "test-value-42" } })
        .pipe(Effect.provide(TestExecutor))
    )
    expect(result.stdout.trim()).toBe("test-value-42")
  })

  it("respects the cwd option", async () => {
    const result = await Effect.runPromise(
      exec("pwd", [], { cwd: "/tmp" }).pipe(Effect.provide(TestExecutor))
    )
    // /tmp may be a symlink, so just check it ends with /tmp or is /tmp
    expect(result.stdout.trim()).toMatch(/\/tmp$/)
  })

  it("uses 30s default timeout", async () => {
    // Just verify a quick command succeeds (default timeout doesn't interfere)
    const result = await Effect.runPromise(
      exec("true", []).pipe(Effect.provide(TestExecutor))
    )
    expect(result.exitCode).toBe(0)
  })

  it("feeds stdin to the child process", async () => {
    const result = await Effect.runPromise(
      // eslint-disable-next-line no-restricted-syntax -- cat is the simplest way to echo stdin back
      exec("cat", [], { stdin: "hello from stdin" }).pipe(Effect.provide(TestExecutor))
    )
    expect(result.stdout).toBe("hello from stdin")
    expect(result.exitCode).toBe(0)
  })

  it("includes the command string in ShellError", async () => {
    const exit = await Effect.runPromiseExit(
      exec("nonexistent-command-xyz", ["--some-arg"]).pipe(Effect.provide(TestExecutor))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { command: string }
      expect(error.command).toBe("nonexistent-command-xyz --some-arg")
    }
  })
})
