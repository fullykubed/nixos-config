import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { FileSystem, Path } from "@effect/platform"
import { commonDir } from "./common-dir"
import { ProjectPath, GitCommonPath } from "../types"
import { ShellService, ShellError } from "../../Shell"

// ── Helpers ───────────────────────────────────────────────────────────

const notRepoError = (cmd: string, args: string[]) =>
  new ShellError({
    command: `${cmd} ${args.join(" ")}`,
    exitCode: 1,
    stderr: "fatal: not a git repository",
    stdout: "",
  })

const mockShellService = (stdout: string, shouldFail = false) =>
  ShellService.of({
    exec: (cmd, args) => {
      if (shouldFail) return Effect.fail(notRepoError(cmd, [...args]))
      return Effect.succeed({ stdout, stderr: "", exitCode: 0 })
    },
    execJson: () => Effect.succeed({}) as any,
    execLines: () => Effect.succeed([]) as any,
  })

/** FileSystem mock that reports stat info. Keys are paths, values are file types. */
const mockFs = (entries: Record<string, "Directory" | "File"> = {}) =>
  ({
    stat: (path: string) => {
      const type = entries[path]
      if (!type) return Effect.fail(new Error("ENOENT"))
      return Effect.succeed({ type })
    },
  }) as any

const mockPath = {
  join: (...parts: string[]) => parts.join("/"),
} as any

const provide = (shell: any, fs?: any, p?: any) =>
  Context.empty().pipe(
    Context.add(ShellService, shell),
    Context.add(FileSystem.FileSystem, fs ?? mockFs()),
    Context.add(Path.Path, p ?? mockPath),
  )

// ── Tests ─────────────────────────────────────────────────────────────

describe("commonDir", () => {
  it("should return the git common dir path", async () => {
    const result = await Effect.runPromise(
      commonDir(ProjectPath("/some/project")).pipe(Effect.provide(provide(mockShellService("/home/user/repo/.git"))))
    )
    expect(result).toBe(GitCommonPath("/home/user/repo/.git"))
  })

  it("should pass cwd option to shell", async () => {
    let capturedOpts: any = undefined
    const shell = ShellService.of({
      exec: (cmd, args, opts) => {
        capturedOpts = opts
        return Effect.succeed({ stdout: "/repo/.git", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    await Effect.runPromise(
      commonDir(ProjectPath("/some/path")).pipe(Effect.provide(provide(shell)))
    )

    expect(capturedOpts).toEqual({ cwd: "/some/path" })
  })

  it("should pass correct git arguments", async () => {
    let capturedArgs: string[] = []
    const shell = ShellService.of({
      exec: (cmd, args) => {
        capturedArgs = [...args]
        return Effect.succeed({ stdout: "/repo/.git", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    await Effect.runPromise(
      commonDir(ProjectPath("/some/project")).pipe(Effect.provide(provide(shell)))
    )

    expect(capturedArgs).toEqual(["rev-parse", "--path-format=absolute", "--git-common-dir"])
  })

  it("should fail with GitNotRepoError when not a git repo and no .bare", async () => {
    const exit = await Effect.runPromiseExit(
      commonDir(ProjectPath("/some/dir")).pipe(Effect.provide(provide(
        mockShellService("", true),
        mockFs(),  // .bare does not exist
      )))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitNotRepoError")
    }
  })

  it("should retry from .bare when not a repo but .bare exists", async () => {
    let callCount = 0
    const shell = ShellService.of({
      exec: (cmd, args, _opts) => {
        callCount++
        if (callCount === 1) {
          // First call (cwd) — not a repo
          return Effect.fail(notRepoError(cmd, [...args]))
        }
        // Second call (from .bare) — success
        return Effect.succeed({ stdout: "/home/user/repo/.bare\n", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const result = await Effect.runPromise(
      commonDir(ProjectPath("/home/user/repo")).pipe(Effect.provide(provide(
        shell,
        mockFs({ "/home/user/repo/.bare": "Directory" }),
      )))
    )

    expect(callCount).toBe(2)
    expect(result).toBe(GitCommonPath("/home/user/repo/.bare"))
  })

  it("should pass .bare path as cwd on retry", async () => {
    const cwds: (string | undefined)[] = []
    const shell = ShellService.of({
      exec: (cmd, args, opts) => {
        const cwd = (opts as any)?.cwd as string | undefined
        cwds.push(cwd)
        if (cwds.length === 1) {
          return Effect.fail(notRepoError(cmd, [...args]))
        }
        return Effect.succeed({ stdout: "/home/user/repo/.bare\n", stderr: "", exitCode: 0 })
      },
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    await Effect.runPromise(
      commonDir(ProjectPath("/home/user/repo")).pipe(Effect.provide(provide(
        shell,
        mockFs({ "/home/user/repo/.bare": "Directory" }),
      )))
    )

    expect(cwds).toEqual(["/home/user/repo", "/home/user/repo/.bare"])
  })

  it("should not retry when .bare is a file, not a directory", async () => {
    const exit = await Effect.runPromiseExit(
      commonDir(ProjectPath("/home/user/repo")).pipe(Effect.provide(provide(
        mockShellService("", true),
        mockFs({ "/home/user/repo/.bare": "File" }),
      )))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitNotRepoError")
    }
  })

  it("should fail with GitUnknownError on other shell errors", async () => {
    const shell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git rev-parse --path-format=absolute --git-common-dir",
        exitCode: 1,
        stderr: "fatal: some unexpected error",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const exit = await Effect.runPromiseExit(
      commonDir(ProjectPath("/some/project")).pipe(Effect.provide(provide(shell)))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitUnknownError")
    }
  })
})
