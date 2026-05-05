import { describe, it, expect } from "bun:test"
import { Context, Effect } from "effect"
import { SilentLogger } from "../../../lib/test-logger"
import { createHandler } from "./handler"
import { GitService, ProjectPath, WorktreePath, BranchName } from "../../../services/Git"
import type { GitServiceShape } from "../../../services/Git"
import { MuxService, MuxBranchExistsOnRemoteError, MuxBranchExistsLocallyError, MuxWorktreePathConflictError, MuxCreateWorktreeError } from "../../../services/Mux"
import type { MuxServiceShape } from "../../../services/Mux"
import type { Parsed } from "./command"

// ── Test Helpers ─────────────────────────────────────────────────────

const mockParsedCommand: Parsed = {
  group: "mux",
  command: "create",
  args: { branch: BranchName("test-branch") },
  flags: {},
  raw: ["mux", "create", "test-branch"]
}

const mockContext = (overrides: {
  mux?: Partial<MuxServiceShape>
  git?: Partial<GitServiceShape>
} = {}) => {
  return Context.empty().pipe(
    Context.add(MuxService, {
      createWorktree: () => Effect.void,
      ...overrides.mux,
    } as any),
    Context.add(GitService, {
      repoRoot: () => Effect.succeed(WorktreePath("/repo")),
      projectDir: () => Effect.succeed(ProjectPath("/repo")),
      ...overrides.git,
    } as any),
  )
}

// ── Tests ────────────────────────────────────────────────────────────

describe("createHandler", () => {
  it("calls mux.createWorktree with projectPath and branch", async () => {
    let capturedProjectPath: ProjectPath | undefined
    let capturedBranch: string | undefined

    await Effect.runPromise(
      createHandler(mockParsedCommand).pipe(
        Effect.provide(mockContext({
          mux: {
            createWorktree: (projectPath, branch) => {
              capturedProjectPath = projectPath
              capturedBranch = branch
              return Effect.void
            }
          }
        })),
        Effect.provide(SilentLogger),
      )
    )

    expect(capturedProjectPath).toBe(ProjectPath("/repo"))
    expect(capturedBranch).toBe("test-branch")
  })

  it("formats MuxBranchExistsOnRemoteError and preserves cause", async () => {
    const original = new MuxBranchExistsOnRemoteError({ branch: "test-branch" })
    const exit = await Effect.runPromiseExit(
      createHandler(mockParsedCommand).pipe(
        Effect.provide(mockContext({
          mux: { createWorktree: () => Effect.fail(original) }
        })),
        Effect.provide(SilentLogger),
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error.message).toContain("already exists on origin")
      expect(exit.cause.error.cause).toBe(original)
    }
  })

  it("formats MuxBranchExistsLocallyError (hasWorktree=true) and preserves cause", async () => {
    const original = new MuxBranchExistsLocallyError({ branch: "test-branch", hasWorktree: true })
    const exit = await Effect.runPromiseExit(
      createHandler(mockParsedCommand).pipe(
        Effect.provide(mockContext({
          mux: { createWorktree: () => Effect.fail(original) }
        })),
        Effect.provide(SilentLogger),
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error.message).toContain("already has a worktree")
      expect(exit.cause.error.cause).toBe(original)
    }
  })

  it("formats MuxBranchExistsLocallyError (hasWorktree=false) and preserves cause", async () => {
    const original = new MuxBranchExistsLocallyError({ branch: "test-branch", hasWorktree: false })
    const exit = await Effect.runPromiseExit(
      createHandler(mockParsedCommand).pipe(
        Effect.provide(mockContext({
          mux: { createWorktree: () => Effect.fail(original) }
        })),
        Effect.provide(SilentLogger),
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error.message).toContain("already exists")
      expect(exit.cause.error.cause).toBe(original)
    }
  })

  it("formats MuxWorktreePathConflictError and preserves cause", async () => {
    const original = new MuxWorktreePathConflictError({ path: "/repo/test-branch" })
    const exit = await Effect.runPromiseExit(
      createHandler(mockParsedCommand).pipe(
        Effect.provide(mockContext({
          mux: { createWorktree: () => Effect.fail(original) }
        })),
        Effect.provide(SilentLogger),
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error.message).toContain("/repo/test-branch")
      expect(exit.cause.error.message).toContain("Remove it")
      expect(exit.cause.error.cause).toBe(original)
    }
  })

  it("formats MuxCreateWorktreeError and preserves cause", async () => {
    const original = new MuxCreateWorktreeError({ branch: "test-branch", cause: new Error("db write failed") })
    const exit = await Effect.runPromiseExit(
      createHandler(mockParsedCommand).pipe(
        Effect.provide(mockContext({
          mux: { createWorktree: () => Effect.fail(original) }
        })),
        Effect.provide(SilentLogger),
      )
    )

    expect(exit._tag).toBe("Failure")
    if (exit._tag === "Failure" && exit.cause._tag === "Fail") {
      expect(exit.cause.error.message).toContain("test-branch")
      expect(exit.cause.error.message).toContain("db write failed")
      expect(exit.cause.error.cause).toBe(original)
    }
  })
})
