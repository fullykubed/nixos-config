import { describe, it, expect } from "bun:test"
import { Effect, Exit, Layer } from "effect"
import { exec } from "./exec"
import { ShellService, ShellError } from "../../Shell"

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return (cause.error as { _tag?: string })._tag
  return undefined
}

const makeShell = (execImpl: (...args: any[]) => any) =>
  Layer.succeed(ShellService, ShellService.of({
    exec: execImpl,
    execJson: (() => Effect.succeed(null)) as any,
    execLines: () => Effect.succeed([]),
  }))

describe("SSH exec success path", () => {
  it("returns stdout/stderr/exitCode on success", async () => {
    const shell = makeShell(() =>
      Effect.succeed({ stdout: "hello from remote\n", stderr: "", exitCode: 0 })
    )

    const result = await Effect.runPromise(
      exec("100.64.0.5", "echo hi").pipe(Effect.provide(shell))
    )
    expect(result.stdout).toBe("hello from remote\n")
    expect(result.stderr).toBe("")
    expect(result.exitCode).toBe(0)
  })

  it("passes the command as the last ssh arg", async () => {
    let capturedArgs: readonly string[] = []
    const shell = makeShell((_cmd: string, args: readonly string[]) => {
      capturedArgs = args
      return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
    })

    await Effect.runPromise(
      exec("10.0.0.1", "uname -a").pipe(Effect.provide(shell))
    )
    // The command should be the last argument
    expect(capturedArgs[capturedArgs.length - 1]).toBe("uname -a")
  })

  it("uses BatchMode=yes for non-interactive exec", async () => {
    let capturedArgs: readonly string[] = []
    const shell = makeShell((_cmd: string, args: readonly string[]) => {
      capturedArgs = args
      return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
    })

    await Effect.runPromise(
      exec("10.0.0.1", "echo test").pipe(Effect.provide(shell))
    )
    expect(capturedArgs).toContain("BatchMode=yes")
  })

  it("uses custom connectTimeout", async () => {
    let capturedOpts: { timeout?: number } = {}
    const shell = makeShell((_cmd: string, _args: readonly string[], opts?: { timeout?: number }) => {
      capturedOpts = opts ?? {}
      return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
    })

    await Effect.runPromise(
      exec("10.0.0.1", "echo", { connectTimeout: 10 }).pipe(Effect.provide(shell))
    )
    expect(capturedOpts.timeout).toBe(10_000) // connectTimeout in seconds → ms
  })

  it("defaults to 30s timeout", async () => {
    let capturedOpts: { timeout?: number } = {}
    const shell = makeShell((_cmd: string, _args: readonly string[], opts?: { timeout?: number }) => {
      capturedOpts = opts ?? {}
      return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
    })

    await Effect.runPromise(
      exec("10.0.0.1", "echo").pipe(Effect.provide(shell))
    )
    expect(capturedOpts.timeout).toBe(30_000)
  })

  it("classifies 'No route to host' as SshConnectionError", async () => {
    const shell = makeShell(() =>
      Effect.fail(new ShellError({ command: "ssh", exitCode: 255, stdout: "", stderr: "No route to host" }))
    )

    const exit = await Effect.runPromiseExit(
      exec("10.0.0.1", "echo").pipe(Effect.provide(shell))
    )
    expect(extractFailureTag(exit)).toBe("SshConnectionError")
  })

  it("classifies 'Authentication failed' as SshAuthError", async () => {
    const shell = makeShell(() =>
      Effect.fail(new ShellError({ command: "ssh", exitCode: 255, stdout: "", stderr: "Authentication failed" }))
    )

    const exit = await Effect.runPromiseExit(
      exec("10.0.0.1", "echo").pipe(Effect.provide(shell))
    )
    expect(extractFailureTag(exit)).toBe("SshAuthError")
  })

  it("classifies 'REMOTE HOST IDENTIFICATION HAS CHANGED' as SshHostKeyError", async () => {
    const shell = makeShell(() =>
      Effect.fail(new ShellError({ command: "ssh", exitCode: 255, stdout: "", stderr: "REMOTE HOST IDENTIFICATION HAS CHANGED" }))
    )

    const exit = await Effect.runPromiseExit(
      exec("10.0.0.1", "echo").pipe(Effect.provide(shell))
    )
    expect(extractFailureTag(exit)).toBe("SshHostKeyError")
  })

  it("classifies 'Timeout' as SshTimeoutError", async () => {
    const shell = makeShell(() =>
      Effect.fail(new ShellError({ command: "ssh", exitCode: 255, stdout: "", stderr: "Timeout connecting" }))
    )

    const exit = await Effect.runPromiseExit(
      exec("10.0.0.1", "echo").pipe(Effect.provide(shell))
    )
    expect(extractFailureTag(exit)).toBe("SshTimeoutError")
  })

  it("defaults to SshConnectionError for unknown errors", async () => {
    const shell = makeShell(() =>
      Effect.fail(new ShellError({ command: "ssh", exitCode: 1, stdout: "", stderr: "some unknown error" }))
    )

    const exit = await Effect.runPromiseExit(
      exec("10.0.0.1", "echo").pipe(Effect.provide(shell))
    )
    expect(extractFailureTag(exit)).toBe("SshConnectionError")
  })

  it("passes knownHostsFile to ssh args", async () => {
    let capturedArgs: readonly string[] = []
    const shell = makeShell((_cmd: string, args: readonly string[]) => {
      capturedArgs = args
      return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
    })

    await Effect.runPromise(
      exec("10.0.0.1", "echo", { knownHostsFile: "/tmp/known_hosts" }).pipe(
        Effect.provide(shell)
      )
    )
    expect(capturedArgs.join(" ")).toContain("UserKnownHostsFile=/tmp/known_hosts")
  })

  it("passes custom port and user", async () => {
    let capturedArgs: readonly string[] = []
    const shell = makeShell((_cmd: string, args: readonly string[]) => {
      capturedArgs = args
      return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
    })

    await Effect.runPromise(
      exec("10.0.0.1", "echo", { port: 22, user: "root" }).pipe(
        Effect.provide(shell)
      )
    )
    expect(capturedArgs).toContain("22")
    expect(capturedArgs.join(" ")).toContain("root@10.0.0.1")
  })
})
