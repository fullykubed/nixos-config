import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { SilentLogger } from "../../../lib/test/logger"
import { FileSystem } from "@effect/platform"
import { ShellService, ShellError } from "../../Shell"
import { send } from "./send"

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return (cause.error as { _tag?: string })._tag
  return undefined
}

const successShell = ShellService.of({
  exec: () => Effect.succeed({ stdout: "", stderr: "", exitCode: 0 }),
  execJson: () => Effect.succeed({}),
  execLines: () => Effect.succeed([]),
} as any)

const failingShell = ShellService.of({
  exec: () => Effect.fail(new ShellError({
    command: "croc send",
    exitCode: 1,
    stdout: "",
    stderr: "connection refused"
  })),
  execJson: () => Effect.succeed({}),
  execLines: () => Effect.succeed([]),
} as any)

const mockFs = FileSystem.FileSystem.of({
  makeTempDirectoryScoped: () => Effect.succeed("/tmp/croc-send-mock"),
} as any)

const failingFs = FileSystem.FileSystem.of({
  makeTempDirectoryScoped: () => Effect.fail(new Error("cannot create tmp")),
} as any)

const provide = (shell: typeof successShell, fs: typeof mockFs) =>
  <A, E>(effect: Effect.Effect<A, E, any>) =>
    effect.pipe(
      Effect.provide(
        Context.empty().pipe(
          Context.add(ShellService, shell),
          Context.add(FileSystem.FileSystem, fs),
        )
      ),
      Effect.provide(SilentLogger),
    ) as Effect.Effect<A, E>

describe("send", () => {
  it("succeeds when croc send works on first attempt", async () => {
    await Effect.runPromise(
      send("/path/to/secrets.tar", { code: "abc123", relayPass: "pass" }).pipe(
        provide(successShell, mockFs),
        Effect.scoped,
      )
    )
  })

  it("passes correct arguments to croc", async () => {
    let capturedCmd = ""
    let capturedArgs: readonly string[] = []
    let capturedOpts: { env?: Record<string, string>; cwd?: string } = {}
    const spyShell = ShellService.of({
      exec: (cmd: string, args: readonly string[], opts?: any) => {
        capturedCmd = cmd
        capturedArgs = args
        capturedOpts = opts ?? {}
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}),
      execLines: () => Effect.succeed([]),
    } as any)

    await Effect.runPromise(
      send("/path/to/file", { code: "mycode", relayPass: "mypass" }).pipe(
        provide(spyShell, mockFs),
        Effect.scoped,
      )
    )
    expect(capturedCmd).toBe("croc")
    expect(capturedArgs).toContain("send")
    expect(capturedArgs).toContain("/path/to/file")
    expect(capturedArgs).toContain("--pass")
    expect(capturedArgs).toContain("mypass")
    expect(capturedOpts.env?.CROC_SECRET).toBe("mycode")
    expect(capturedOpts.cwd).toBe("/tmp/croc-send-mock")
  })

  it("fails with CrocSendError after exhausting retries", async () => {
    const exit = await Effect.runPromiseExit(
      send("/path/to/file", { code: "abc", relayPass: "pass", maxRetries: 1, timeout: 100 }).pipe(
        provide(failingShell, mockFs),
        Effect.scoped,
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("CrocSendError")
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { target: string; attempts: number }
      expect(error.target).toBe("/path/to/file")
      expect(error.attempts).toBe(1)
    }
  })

  it("fails with CrocSendError when temp dir creation fails", async () => {
    const exit = await Effect.runPromiseExit(
      send("/path/to/file", { code: "abc", relayPass: "pass" }).pipe(
        provide(successShell, failingFs),
        Effect.scoped,
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("CrocSendError")
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { message: string }
      expect(error.message).toContain("temporary directory")
    }
  })

  it("uses default timeout and maxRetries", async () => {
    let capturedOpts: { timeout?: number } = {}
    const spyShell = ShellService.of({
      exec: (_cmd: string, _args: readonly string[], opts?: any) => {
        capturedOpts = opts ?? {}
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}),
      execLines: () => Effect.succeed([]),
    } as any)

    await Effect.runPromise(
      send("/file", { code: "c", relayPass: "p" }).pipe(
        provide(spyShell, mockFs),
        Effect.scoped,
      )
    )
    expect(capturedOpts.timeout).toBe(120_000)
  })
})
