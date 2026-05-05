import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { ShellService, ShellError } from "../../Shell"
import { isReachable } from "./is-reachable"

const successShell = ShellService.of({
  exec: () => Effect.succeed({ stdout: "", stderr: "", exitCode: 0 }),
  execJson: () => Effect.succeed({}),
  execLines: () => Effect.succeed([]),
} as any)

const failingShell = ShellService.of({
  exec: () => Effect.fail(new ShellError({
    command: "nc",
    exitCode: 1,
    stdout: "",
    stderr: "Connection refused"
  })),
  execJson: () => Effect.succeed({}),
  execLines: () => Effect.succeed([]),
} as any)

describe("isReachable", () => {
  it("returns true when nc succeeds", async () => {
    const result = await Effect.runPromise(
      isReachable("builder-1", 22).pipe(
        Effect.provideService(ShellService, successShell)
      )
    )
    expect(result).toBe(true)
  })

  it("returns false when nc fails", async () => {
    const result = await Effect.runPromise(
      isReachable("builder-1", 22).pipe(
        Effect.provideService(ShellService, failingShell)
      )
    )
    expect(result).toBe(false)
  })

  it("never fails — always returns boolean", async () => {
    // Even with a failing shell, isReachable should succeed with false
    const result = await Effect.runPromise(
      isReachable("nonexistent-host", 9999).pipe(
        Effect.provideService(ShellService, failingShell)
      )
    )
    expect(typeof result).toBe("boolean")
  })

  it("passes correct host and port to nc", async () => {
    let capturedArgs: readonly string[] = []
    const spyShell = ShellService.of({
      exec: (_cmd: string, args: readonly string[]) => {
        capturedArgs = args
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}),
      execLines: () => Effect.succeed([]),
    } as any)

    await Effect.runPromise(
      isReachable("100.64.0.5", 3098).pipe(
        Effect.provideService(ShellService, spyShell)
      )
    )
    expect(capturedArgs).toContain("100.64.0.5")
    expect(capturedArgs).toContain("3098")
  })
})
