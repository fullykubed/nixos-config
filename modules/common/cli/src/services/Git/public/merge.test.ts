import { Effect, Exit } from "effect"
import { describe, test, expect } from "bun:test"
import { ShellService, ShellError } from "../../Shell"
import { merge } from "./merge"
import { BranchName, WorktreePath } from "../types"

const mockShellService = (responses: Record<string, { stdout: string; stderr?: string; exitCode?: number; shouldFail?: boolean }> = {}) => ({
    exec: (cmd: string, args: readonly string[], _opts?: any) => {
      const commandKey = `${cmd} ${args.join(" ")}`
      const response = responses[commandKey]

      if (response?.shouldFail) {
        return Effect.fail(new ShellError({
          command: commandKey,
          exitCode: response.exitCode ?? 1,
          stderr: response.stderr ?? "command failed",
          stdout: response.stdout,
        }))
      }

      return Effect.succeed({
        stdout: response?.stdout ?? "",
        stderr: response?.stderr ?? "",
        exitCode: response?.exitCode ?? 0
      })
    },
    execJson: <T>() => Effect.succeed({} as T),
    execLines: () => Effect.succeed([]),
  })

describe("Git merge operations", () => {
  test("merge executes git merge command", async () => {
    const shell = mockShellService({
      "git merge feature-branch": { stdout: "", stderr: "", exitCode: 0 }
    })

    await merge(BranchName("feature-branch"), WorktreePath("/some/path")).pipe(
      Effect.provideService(ShellService, shell),
      Effect.runPromise
    )
  })

  test("merge with cwd passes directory option", async () => {
    let capturedOpts: any = undefined
    const shell = {
      exec: (cmd: string, args: readonly string[], opts?: any) => {
        capturedOpts = opts
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    }

    await merge(BranchName("feature-branch"), WorktreePath("/custom/path")).pipe(
      Effect.provideService(ShellService, shell),
      Effect.runPromise
    )

    expect(capturedOpts).toEqual({ cwd: "/custom/path" })
  })


  test("merge failure returns GitError", async () => {
    const shell = mockShellService({
      "git merge feature-branch": { stdout: "", stderr: "merge failed", exitCode: 1, shouldFail: true }
    })

    const exit = await merge(BranchName("feature-branch"), WorktreePath("/some/path")).pipe(
      Effect.provideService(ShellService, shell),
      Effect.runPromiseExit
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitUnknownError")
    }
  })
})