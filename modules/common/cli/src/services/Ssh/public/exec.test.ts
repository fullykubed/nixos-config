import { describe, it, expect } from "bun:test"
import { Effect, Exit, Layer } from "effect"
import { exec } from "./exec"
import { ShellService, ShellError } from "../../Shell"

const makeMockShell = (stderr: string) =>
  Layer.succeed(ShellService, ShellService.of({
    exec: () => Effect.fail(new ShellError({
      command: "ssh",
      exitCode: 255,
      stdout: "",
      stderr,
    })),
    execJson: () => Effect.fail(new ShellError({
      command: "ssh",
      exitCode: 255,
      stdout: "",
      stderr,
    })),
    execLines: () => Effect.fail(new ShellError({
      command: "ssh",
      exitCode: 255,
      stdout: "",
      stderr,
    })),
  }))

function extractFailureTag(exit: Exit.Exit<any, any>): string | undefined {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return (cause.error)?._tag
  return undefined
}

describe("SSH error classification", () => {
  it("classifies 'Connection refused' as SshConnectionError", async () => {
    const mockShell = makeMockShell("Connection refused")
    const exit = await Effect.runPromiseExit(
      exec("10.0.0.1", "echo hi").pipe(
        Effect.provide(mockShell)
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("SshConnectionError")
  })

  it("classifies 'Permission denied' as SshAuthError", async () => {
    const mockShell = makeMockShell("Permission denied (publickey)")
    const exit = await Effect.runPromiseExit(
      exec("10.0.0.1", "echo hi").pipe(
        Effect.provide(mockShell)
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("SshAuthError")
  })

  it("classifies 'timed out' as SshTimeoutError", async () => {
    const mockShell = makeMockShell("Connection timed out")
    const exit = await Effect.runPromiseExit(
      exec("10.0.0.1", "echo hi").pipe(
        Effect.provide(mockShell)
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("SshTimeoutError")
  })

  it("classifies 'Host key verification failed' as SshHostKeyError", async () => {
    const mockShell = makeMockShell("Host key verification failed")
    const exit = await Effect.runPromiseExit(
      exec("10.0.0.1", "echo hi").pipe(
        Effect.provide(mockShell)
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("SshHostKeyError")
  })
})