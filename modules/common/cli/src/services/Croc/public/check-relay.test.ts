import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { ShellService, ShellError } from "../../Shell"
import { checkRelay } from "./check-relay"

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return (cause.error as { _tag?: string })._tag
  return undefined
}

describe("checkRelay", () => {
  it("succeeds when nc succeeds", async () => {
    const shell = ShellService.of({
      exec: () => Effect.succeed({ stdout: "", stderr: "", exitCode: 0 }),
      execJson: () => Effect.succeed({}),
      execLines: () => Effect.succeed([]),
    } as any)

    await Effect.runPromise(
      checkRelay().pipe(Effect.provideService(ShellService, shell))
    )
  })

  it("fails with CrocRelayUnreachableError when nc fails", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "nc",
        exitCode: 1,
        stdout: "",
        stderr: "Connection refused"
      })),
      execJson: () => Effect.succeed({}),
      execLines: () => Effect.succeed([]),
    } as any)

    const exit = await Effect.runPromiseExit(
      checkRelay().pipe(Effect.provideService(ShellService, shell))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("CrocRelayUnreachableError")
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { relayAddress: string }
      expect(error.relayAddress).toContain("panfactumcf.com")
    }
  })

  it("passes the correct host and port to nc", async () => {
    let capturedCmd = ""
    let capturedArgs: readonly string[] = []
    const shell = ShellService.of({
      exec: (cmd: string, args: readonly string[]) => {
        capturedCmd = cmd
        capturedArgs = args
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}),
      execLines: () => Effect.succeed([]),
    } as any)

    await Effect.runPromise(
      checkRelay().pipe(Effect.provideService(ShellService, shell))
    )
    expect(capturedCmd).toBe("nc")
    expect(capturedArgs).toContain("-z")
    expect(capturedArgs).toContain("-w")
    expect(capturedArgs).toContain("headscale.panfactumcf.com")
    expect(capturedArgs).toContain("19009")
  })
})
