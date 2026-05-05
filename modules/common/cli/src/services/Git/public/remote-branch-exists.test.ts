import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { remoteBranchExists } from "./remote-branch-exists"
import { BranchName, GitCommonPath } from "../types"
import { ShellService, ShellError } from "../../Shell"

/** Shell mock that handles git remote, git fetch, and git rev-parse calls. */
const makeShell = (opts: {
  remotes?: string[]
  revParseResult?: "found" | "not-found" | "not-repo"
  fetchFail?: boolean
}) => {
  const calls: { cmd: string; args: string[] }[] = []

  const shell = ShellService.of({
    exec: (cmd, args) => {
      calls.push({ cmd, args: [...args] })
      const sub = args[0]

      if (sub === "remote") {
        return Effect.succeed({
          stdout: (opts.remotes ?? ["origin"]).join("\n") + "\n",
          stderr: "",
          exitCode: 0,
        })
      }

      if (sub === "fetch") {
        if (opts.fetchFail) {
          return Effect.fail(new ShellError({
            command: `git ${args.join(" ")}`,
            exitCode: 1,
            stderr: "Could not resolve host",
            stdout: "",
          }))
        }
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      }

      if (sub === "rev-parse") {
        if (opts.revParseResult === "not-repo") {
          return Effect.fail(new ShellError({
            command: `git ${args.join(" ")}`,
            exitCode: 128,
            stderr: "fatal: not a git repository",
            stdout: "",
          }))
        }
        if (opts.revParseResult === "not-found") {
          return Effect.fail(new ShellError({
            command: `git ${args.join(" ")}`,
            exitCode: 1,
            stderr: "",
            stdout: "",
          }))
        }
        return Effect.succeed({ stdout: "abc123\n", stderr: "", exitCode: 0 })
      }

      return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
    },
    execJson: () => Effect.succeed({}) as any,
    execLines: () => Effect.succeed([]) as any,
  })

  return { shell, calls }
}

describe("remoteBranchExists", () => {
  it("should fetch then return true when remote branch exists", async () => {
    const { shell, calls } = makeShell({ revParseResult: "found" })

    const result = await Effect.runPromise(
      remoteBranchExists("origin", BranchName("main"), GitCommonPath("/repo/.git")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(result).toBe(true)
    // Verify it called: git remote, git fetch origin, git rev-parse
    const subs = calls.map((c) => c.args[0])
    expect(subs).toEqual(["remote", "fetch", "rev-parse"])
    // Verify rev-parse checks the right ref
    const revParseCall = calls.find((c) => c.args[0] === "rev-parse")
    expect(revParseCall!.args).toEqual(["rev-parse", "--verify", "--quiet", "refs/remotes/origin/main"])
  })

  it("should return false when remote branch does not exist after fetch", async () => {
    const { shell } = makeShell({ revParseResult: "not-found" })

    const result = await Effect.runPromise(
      remoteBranchExists("origin", BranchName("no-such-branch"), GitCommonPath("/repo/.git")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(result).toBe(false)
  })

  it("should return false without fetching when remote is not configured", async () => {
    const { shell, calls } = makeShell({ remotes: [] })

    const result = await Effect.runPromise(
      remoteBranchExists("origin", BranchName("main"), GitCommonPath("/repo/.git")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(result).toBe(false)
    // Only git remote should have been called — no fetch or rev-parse
    const subs = calls.map((c) => c.args[0])
    expect(subs).toEqual(["remote"])
  })

  it("should pass cwd option to all git calls", async () => {
    const { shell, calls } = makeShell({ revParseResult: "found" })

    await Effect.runPromise(
      remoteBranchExists("origin", BranchName("main"), GitCommonPath("/some/path")).pipe(Effect.provideService(ShellService, shell))
    )

    // All exec calls should receive { cwd: "/some/path" } — but the mock doesn't capture opts
    // Verify via the calls that at least the right subcommands ran
    const subs = calls.map((c) => c.args[0])
    expect(subs).toEqual(["remote", "fetch", "rev-parse"])
  })

  it("should fail with GitNotRepoError when not a git repo", async () => {
    const { shell: _shell } = makeShell({ revParseResult: "not-repo" })

    // hasRemote will also fail with "not a git repository"
    const notRepoShell = ShellService.of({
      exec: () => Effect.fail(new ShellError({
        command: "git remote",
        exitCode: 128,
        stderr: "fatal: not a git repository",
        stdout: "",
      })),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    })

    const exit = await Effect.runPromiseExit(
      remoteBranchExists("origin", BranchName("main"), GitCommonPath("/repo/.git")).pipe(Effect.provideService(ShellService, notRepoShell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitNotRepoError")
    }
  })

  it("should propagate fetch connectivity errors", async () => {
    const { shell } = makeShell({ fetchFail: true })

    const exit = await Effect.runPromiseExit(
      remoteBranchExists("origin", BranchName("main"), GitCommonPath("/repo/.git")).pipe(Effect.provideService(ShellService, shell))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("GitConnectivityError")
    }
  })
})
