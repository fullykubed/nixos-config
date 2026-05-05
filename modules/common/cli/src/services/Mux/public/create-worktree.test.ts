import { describe, it, expect } from "bun:test"
import nodePath from "node:path"
import { Context, Effect, Fiber, Option } from "effect"
import { SilentLogger } from "../../../lib/test/logger"
import { FileSystem, Path } from "@effect/platform"
import { createWorktree } from "./create-worktree"
import { GitService, GitCommonPath, WorktreePath, BranchName, ProjectPath, GitUnknownError } from "../../Git"
import { mockGetProjectConfig } from "../../Git/public/get-project-config.mock"
import type { GitServiceShape } from "../../Git"
import { TmuxService } from "../../Tmux"
import type { TmuxServiceShape } from "../../Tmux"
import { ShellService } from "../../Shell"
import { StoreService } from "../../Store"

// ── Test Helpers ─────────────────────────────────────────────────────

/** Builds a chainable Kysely-like mock that resolves to `result` at any terminal method. */
const kyselyChain = (result: unknown): any => {
  const chain: any = new Proxy({}, {
    get: (_target, prop) => {
      if (prop === "then" || prop === "catch") return
      if (prop === "executeTakeFirst") {
        return () => Promise.resolve(result)
      }
      if (prop === "executeTakeFirstOrThrow") {
        return () => {
          if (result === undefined || result === null) {
            return Promise.reject(new Error("No result returned"))
          }
          return Promise.resolve(result)
        }
      }
      if (prop === "execute") {
        return () => Promise.resolve(result)
      }
      return (..._args: unknown[]) => chain
    }
  })
  return chain
}

/** Chain that always rejects at any terminal method. */
const kyselyRejectChain = (error = new Error("DB error")): any => {
  const chain: any = new Proxy({}, {
    get: (_target, prop) => {
      if (prop === "then" || prop === "catch") return
      if (prop === "executeTakeFirst" || prop === "executeTakeFirstOrThrow" || prop === "execute") {
        return () => Promise.reject(error)
      }
      return (..._args: unknown[]) => chain
    }
  })
  return chain
}

const mockStore = (overrides?: { projectResult?: unknown; worktreeRejects?: boolean; selectResult?: unknown }) => ({
  insertInto: (table: string) => {
    if (table === "mux_projects") return kyselyChain(overrides && "projectResult" in overrides ? overrides.projectResult : { id: 1 })
    if (overrides?.worktreeRejects) return kyselyRejectChain()
    return kyselyChain({ id: "mock-wt-id" })
  },
  selectFrom: () => kyselyChain(overrides && "selectResult" in overrides ? overrides.selectResult : { id: 1, path: "/home/user/repo" }),
  updateTable: () => kyselyChain(undefined),
  deleteFrom: () => kyselyChain(undefined),
})

const mockContext = (overrides: {
  tmux?: Partial<TmuxServiceShape>
  git?: Partial<GitServiceShape>
  store?: ReturnType<typeof mockStore>
} = {}) => {
  return Context.empty().pipe(
    Context.add(TmuxService, {
      isInsideTmux: () => Effect.succeed(true),
      currentSession: () => Effect.succeed("default"),
      ensureSession: () => Effect.void,
      setSessionOption: () => Effect.void,
      setWindowOption: () => Effect.void,
      sessionExists: () => Effect.succeed(true),
      renameSession: () => Effect.void,
      findWindow: () => Effect.succeed(Option.none()),
      createWindow: () => Effect.succeed("@0"),
      killWindow: () => Effect.void,
      switchWindow: () => Effect.void,
      splitPane: () => Effect.void,
      sendKeys: () => Effect.void,
      selectPane: () => Effect.void,
      setPaneOption: () => Effect.void,
      listWindows: () => Effect.succeed([]),
      ...overrides.tmux,
    } as any),
    Context.add(GitService, {
      commonDir: () => Effect.succeed(GitCommonPath("/home/user/repo/.git")),
      projectDir: () => Effect.succeed(ProjectPath("/home/user/repo")),
      primaryWorktreeDir: () => Effect.succeed(WorktreePath("/home/user/repo")),
      worktreeAdd: () => Effect.succeed(WorktreePath("/home/user/repo/test-branch")),
      worktreeRemove: () => Effect.void,
      deleteBranch: () => Effect.void,
      remoteBranchExists: () => Effect.succeed(false),
      worktreeList: () => Effect.succeed([]),
      getProjectConfig: mockGetProjectConfig({ projectPath: ProjectPath("/home/user/repo"), tmux_session: "test" }),
      ...overrides.git,
    } as any),
    Context.add(ShellService, {
      exec: () => Effect.succeed({ stdout: "", stderr: "", exitCode: 0 }),
    } as any),
    Context.add(StoreService, (overrides.store ?? mockStore()) as any),
    Context.add(FileSystem.FileSystem, {
      exists: () => Effect.succeed(false),
      copy: () => Effect.void,
      readFileString: () => Effect.fail(new Error("not found")),
      writeFileString: () => Effect.void,
      remove: () => Effect.void,
    } as any),
    Context.add(Path.Path, {
      join: nodePath.join,
      resolve: nodePath.resolve,
      basename: nodePath.basename,
    } as any),
  )
}

// ── Runners (suppress Effect.log output) ─────────────────────────────

const run = <A, E>(effect: Effect.Effect<A, E, any>) =>
  Effect.runPromise(effect.pipe(Effect.provide(SilentLogger)) as Effect.Effect<A, E>)

const runExit = <A, E>(effect: Effect.Effect<A, E, any>) =>
  Effect.runPromiseExit(effect.pipe(Effect.provide(SilentLogger)) as Effect.Effect<A, E>)

// ── Tests ────────────────────────────────────────────────────────────

describe("createWorktree", () => {
  it("calls GitService.commonDir to get project root", async () => {
    let commonDirCalled = false

    await run(
      createWorktree(ProjectPath("/home/user/repo"), BranchName("test-branch")).pipe(
        Effect.provide(mockContext({
          git: {
            commonDir: () => {
              commonDirCalled = true
              return Effect.succeed(GitCommonPath("/home/user/repo/.git"))
            },
          },
        }))
      )
    )

    expect(commonDirCalled).toBe(true)
  })

  it("calls GitService.worktreeAdd with correct branch and opts", async () => {
    let addBranch: string | undefined
    let addOpts: any

    await run(
      createWorktree(ProjectPath("/home/user/repo"), BranchName("test-branch")).pipe(
        Effect.provide(mockContext({
          git: {
            worktreeAdd: (branch, gitCommonDir, opts) => {
              addBranch = branch
              addOpts = opts
              return Effect.succeed(WorktreePath("/home/user/repo/test-branch"))
            },
          },
        }))
      )
    )

    expect(addBranch).toBe("test-branch")
    expect(addOpts).toEqual({ create: true })
  })

  it("passes projectPath to getProjectConfig", async () => {
    let configArg: string | undefined

    await run(
      createWorktree(ProjectPath("/home/user/repo"), BranchName("test-branch")).pipe(
        Effect.provide(mockContext({
          git: {
            getProjectConfig: (path) => {
              configArg = path
              return mockGetProjectConfig({ projectPath: ProjectPath("/home/user/repo") })(path)
            },
          },
        }))
      )
    )

    expect(configArg).toBe("/home/user/repo")
  })

  it("cleans up worktree and branch, wraps failure in MuxCreateWorktreeError", async () => {
    let worktreeRemoveCalled = false
    let deleteBranchArgs: [string, { force?: boolean; cwd?: string }] | undefined
    let createWindowCalled = false

    const exit = await runExit(
      createWorktree(ProjectPath("/home/user/repo"), BranchName("test-branch")).pipe(
        Effect.provide(mockContext({
          // Force a failure in trackWorktree by making store insertInto fail
          store: mockStore({ worktreeRejects: true }),
          tmux: {
            createWindow: (_name) => {
              createWindowCalled = true
              return Effect.succeed("@77")
            },
          },
          git: {
            getProjectConfig: mockGetProjectConfig({ projectPath: ProjectPath("/home/user/repo") }),
            worktreeRemove: () => {
              worktreeRemoveCalled = true
              return Effect.void
            },
            deleteBranch: (branch, gitCommonDir, opts) => {
              deleteBranchArgs = [branch, opts!]
              return Effect.void
            },
          },
        }))
      )
    )

    expect(exit._tag).toBe("Failure")
    expect(createWindowCalled).toBe(true)  // Verify window creation happened
    expect(worktreeRemoveCalled).toBe(true)
    expect(deleteBranchArgs![0]).toBe("test-branch")
    expect(deleteBranchArgs![1].force).toBe(true)
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("MuxCreateWorktreeError")
      if (exit.cause.error._tag === "MuxCreateWorktreeError") {
        expect(exit.cause.error.branch).toBe("test-branch")
      }
    }
  })

  it("kills tmux window and deletes branch on cleanup when window was already created", async () => {
    let killedWindowId: string | undefined
    let worktreeRemoveCalled = false
    let deleteBranchCalled = false

    const exit = await runExit(
      createWorktree(ProjectPath("/home/user/repo"), BranchName("test-branch")).pipe(
        Effect.provide(mockContext({
          tmux: {
            // createWindow succeeds, returning a window id
            createWindow: () => Effect.succeed("@77"),
            killWindow: (windowId) => {
              killedWindowId = windowId
              return Effect.void
            },
          },
          store: mockStore({ worktreeRejects: true }),
          git: {
            worktreeRemove: () => {
              worktreeRemoveCalled = true
              return Effect.void
            },
            deleteBranch: () => {
              deleteBranchCalled = true
              return Effect.void
            },
          },
        }))
      )
    )

    expect(exit._tag).toBe("Failure")
    expect(killedWindowId).toBe("@77")
    expect(worktreeRemoveCalled).toBe(true)
    expect(deleteBranchCalled).toBe(true)
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("MuxCreateWorktreeError")
    }
  })

  it("does not kill tmux window when failure occurs before window creation", async () => {
    let killWindowCalled = false

    // Create a store where selectFrom throws to fail trackProject before createWindow
    const failingSelectChain: any = new Proxy({}, {
      get: (_target, prop) => {
        if (prop === "then" || prop === "catch") return
        if (prop === "executeTakeFirst" || prop === "executeTakeFirstOrThrow" || prop === "execute") {
          return () => Promise.reject(new Error("DB error"))
        }
        return (..._args: unknown[]) => failingSelectChain
      }
    })
    const failingStore = {
      ...mockStore(),
      selectFrom: () => failingSelectChain,
    }

    const exit = await runExit(
      createWorktree(ProjectPath("/home/user/repo"), BranchName("test-branch")).pipe(
        Effect.provide(mockContext({
          store: failingStore,
          tmux: {
            killWindow: () => {
              killWindowCalled = true
              return Effect.void
            },
          },
        }))
      )
    )

    expect(exit._tag).toBe("Failure")
    expect(killWindowCalled).toBe(false)
  })

  it("fails with MuxBranchExistsLocallyError (hasWorktree=true) when branch has a worktree", async () => {
    const exit = await runExit(
      createWorktree(ProjectPath("/home/user/repo"), BranchName("test-branch")).pipe(
        Effect.provide(mockContext({
          git: {
            worktreeAdd: () => Effect.fail(new GitUnknownError({ message: "fatal: 'test-branch' already exists" })),
            worktreeList: () => Effect.succeed([
              { path: WorktreePath("/home/user/repo"), head: "abc", branch: BranchName("main"), isPrimary: true, bare: false, locked: false, prunable: false },
              { path: WorktreePath("/home/user/test-branch"), head: "def", branch: BranchName("test-branch"), isPrimary: false, bare: false, locked: false, prunable: false },
            ]),
          },
        }))
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("MuxBranchExistsLocallyError")
      if (exit.cause.error._tag === "MuxBranchExistsLocallyError") {
        expect(exit.cause.error.branch).toBe("test-branch")
        expect(exit.cause.error.hasWorktree).toBe(true)
      }
    }
  })

  it("fails with MuxBranchExistsLocallyError (hasWorktree=false) when branch exists without worktree", async () => {
    const exit = await runExit(
      createWorktree(ProjectPath("/home/user/repo"), BranchName("test-branch")).pipe(
        Effect.provide(mockContext({
          git: {
            worktreeAdd: () => Effect.fail(new GitUnknownError({ message: "fatal: 'test-branch' already exists" })),
            worktreeList: () => Effect.succeed([
              { path: WorktreePath("/home/user/repo"), head: "abc", branch: BranchName("main"), isPrimary: true, bare: false, locked: false, prunable: false },
            ]),
          },
        }))
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("MuxBranchExistsLocallyError")
      if (exit.cause.error._tag === "MuxBranchExistsLocallyError") {
        expect(exit.cause.error.hasWorktree).toBe(false)
      }
    }
  })

  it("fails with MuxBranchExistsOnRemoteError when branch exists on origin", async () => {
    const exit = await runExit(
      createWorktree(ProjectPath("/home/user/repo"), BranchName("test-branch")).pipe(
        Effect.provide(mockContext({
          git: {
            remoteBranchExists: (_remote, branch) =>
              Effect.succeed(branch === "test-branch"),
          },
        }))
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("MuxBranchExistsOnRemoteError")
      if (exit.cause.error._tag === "MuxBranchExistsOnRemoteError") {
        expect(exit.cause.error.branch).toBe("test-branch")
      }
    }
  })

  it("proceeds when remote branch does not exist", async () => {
    let worktreeAddCalled = false

    await run(
      createWorktree(ProjectPath("/home/user/repo"), BranchName("test-branch")).pipe(
        Effect.provide(mockContext({
          git: {
            remoteBranchExists: () => Effect.succeed(false),
            worktreeAdd: () => {
              worktreeAddCalled = true
              return Effect.succeed(WorktreePath("/home/user/repo/test-branch"))
            },
          },
        }))
      )
    )

    expect(worktreeAddCalled).toBe(true)
  })

  it("fails with MuxWorktreePathConflictError when path already exists", async () => {
    const exit = await runExit(
      createWorktree(ProjectPath("/home/user/repo"), BranchName("test-branch")).pipe(
        Effect.provide(mockContext({
          git: {
            worktreeAdd: () => Effect.fail(new GitUnknownError({ message: "fatal: '/home/user/repo/test-branch' already exists and is not empty" })),
          },
        }))
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("MuxWorktreePathConflictError")
      if (exit.cause.error._tag === "MuxWorktreePathConflictError") {
        expect(exit.cause.error.path).toBe("test-branch")
      }
    }
  })

  it("cleans up on fiber interruption after window is created", async () => {
    let killedWindowId: string | undefined
    let worktreeRemoveCalled = false
    let resolveReached!: () => void
    const reachedPromise = new Promise<void>(r => { resolveReached = r })

    // Store that hangs on mux_worktrees insert (after createWindow has completed)
    const hangingInsertChain: any = new Proxy({}, {
      get: (_target, prop) => {
        if (prop === "then" || prop === "catch") return
        if (prop === "execute") {
          return () => {
            resolveReached()
            return new Promise((_resolve) => { /* never resolves */ })
          }
        }
        return (..._args: unknown[]) => hangingInsertChain
      },
    })

    const hangStore = {
      ...mockStore(),
      insertInto: (table: string) => {
        if (table === "mux_projects") return kyselyChain({ id: 1 })
        return hangingInsertChain // mux_worktrees hangs
      },
    }

    await run(
      Effect.gen(function* () {
        const fiber = yield* Effect.fork(
          createWorktree(ProjectPath("/home/user/repo"), BranchName("test-branch")).pipe(
            Effect.provide(mockContext({
              tmux: {
                createWindow: () => Effect.succeed("@77"),
                killWindow: (windowId) => {
                  killedWindowId = windowId
                  return Effect.void
                },
              },
              store: hangStore,
              git: {
                worktreeRemove: () => {
                  worktreeRemoveCalled = true
                  return Effect.void
                },
              },
            }))
          )
        )

        yield* Effect.promise(() => reachedPromise)
        yield* Fiber.interrupt(fiber)
      })
    )

    expect(killedWindowId).toBe("@77")
    expect(worktreeRemoveCalled).toBe(true)
  })
})
