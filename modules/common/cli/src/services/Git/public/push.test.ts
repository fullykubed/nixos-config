import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { push } from "./push"
import { ShellService, ShellError } from "../../Shell"
import { WorktreePath } from "../types"

describe("push", () => {
  it("should execute git push command", async () => {
    let capturedArgs: string[] = []
    const shell = {
      exec: (cmd: string, args: readonly string[], _opts?: any) => {
        capturedArgs = [cmd, ...args]
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    }

    await Effect.runPromise(
      push(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedArgs).toEqual(["git", "push"])
  })

  it("should pass cwd option to shell", async () => {
    let capturedOpts: any = undefined
    const shell = {
      exec: (cmd: string, args: readonly string[], opts?: any) => {
        capturedOpts = opts
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    }

    await Effect.runPromise(
      push(WorktreePath("/some/cwd")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(capturedOpts).toEqual({ cwd: "/some/cwd" })
  })

  it("should fail with GitUnknownError on shell error", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git push",
        exitCode: 1,
        stderr: "fatal: The current branch has no upstream branch",
        stdout: "",
      })),
      execJson: <T>() => Effect.succeed({} as T),
      execLines: () => Effect.succeed([]),
    })

    const exit = await Effect.runPromiseExit(
      push(WorktreePath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitUnknownError")
      expect(exit.cause.error.message).toBe("fatal: The current branch has no upstream branch")
    }
  })
})