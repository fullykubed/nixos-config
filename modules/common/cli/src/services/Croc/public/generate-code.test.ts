import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { ShellService, ShellError } from "../../Shell"
import { generateCode } from "./generate-code"

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
    return (exit.cause.error as { _tag?: string })._tag
  }
}

describe("generateCode", () => {
  it("returns trimmed hex code on success", async () => {
    const shell = ShellService.of({
      exec: () => Effect.succeed({ stdout: "a1b2c3d4e5f6a7b8a1b2c3d4e5f6a7b8\n", stderr: "", exitCode: 0 }),
      execJson: () => Effect.succeed({}),
      execLines: () => Effect.succeed([]),
    } as any)

    const code = await Effect.runPromise(
      generateCode().pipe(Effect.provideService(ShellService, shell))
    )
    expect(code).toBe("a1b2c3d4e5f6a7b8a1b2c3d4e5f6a7b8")
    expect(code).toHaveLength(32)
  })

  it("trims whitespace from output", async () => {
    const shell = ShellService.of({
      exec: () => Effect.succeed({ stdout: "  deadbeef12345678deadbeef12345678  \n", stderr: "", exitCode: 0 }),
      execJson: () => Effect.succeed({}),
      execLines: () => Effect.succeed([]),
    } as any)

    const code = await Effect.runPromise(
      generateCode().pipe(Effect.provideService(ShellService, shell))
    )
    expect(code).toBe("deadbeef12345678deadbeef12345678")
  })

  it("fails with CrocCodeError when openssl fails", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "openssl rand -hex 16",
        exitCode: 1,
        stdout: "",
        stderr: "openssl not found"
      })),
      execJson: () => Effect.succeed({}),
      execLines: () => Effect.succeed([]),
    } as any)

    const exit = await Effect.runPromiseExit(
      generateCode().pipe(Effect.provideService(ShellService, shell))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("CrocCodeError")
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { message: string }
      expect(error.message).toContain("openssl")
    }
  })

  it("calls openssl with correct args", async () => {
    let capturedCmd = ""
    let capturedArgs: readonly string[] = []
    const shell = ShellService.of({
      exec: (cmd: string, args: readonly string[]) => {
        capturedCmd = cmd
        capturedArgs = args
        return Effect.succeed({ stdout: "0000000000000000000000000000000\n", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}),
      execLines: () => Effect.succeed([]),
    } as any)

    await Effect.runPromise(
      generateCode().pipe(Effect.provideService(ShellService, shell))
    )
    expect(capturedCmd).toBe("openssl")
    expect(capturedArgs).toEqual(["rand", "-hex", "16"])
  })
})
