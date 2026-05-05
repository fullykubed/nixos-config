import { describe, test, expect } from "bun:test"
import { Effect, Context } from "effect"
import { listHandler } from "./handler"
import { GitService, WorktreePath, BranchName, ProjectPath, GitCommonPath } from "../../../services/Git"
import { mockGetProjectConfig } from "../../../services/Git/public/get-project-config.mock"
import { TmuxService, type TmuxWindow } from "../../../services/Tmux"
import { MuxService, type MuxServiceShape, type MuxWorktreeEntry } from "../../../services/Mux"
import type { Worktree } from "../../../services/Git"

// Capture stdout
const captureStdout = () => {
  const originalWrite = process.stdout.write.bind(process.stdout)
  const chunks: string[] = []

  process.stdout.write = (chunk: string | Uint8Array) => {
    chunks.push(String(chunk))
    return true
  }

  return {
    restore: () => {
      process.stdout.write = originalWrite
    },
    getOutput: () => chunks.join('')
  }
}

describe("listHandler", () => {
  const mockGitService = {
    repoRoot: () => Effect.succeed(WorktreePath("/home/user/repo")),
    projectDir: () => Effect.succeed(ProjectPath("/home/user/repo")),
    commonDir: () => Effect.succeed(GitCommonPath("/home/user/repo/.git")),
    primaryWorktreeDir: () => Effect.succeed(WorktreePath("/home/user/repo")),
    currentBranch: () => Effect.succeed(BranchName("main")),
    isWorktree: () => Effect.succeed(null),
    isDirty: () => Effect.succeed(false),
    getProjectConfig: mockGetProjectConfig({ projectPath: ProjectPath("/home/user/repo") }),
    worktreeList: () => Effect.succeed([
      {
        path: WorktreePath("/home/user/repo"),
        head: "main",
        branch: BranchName("main"),
        isPrimary: true,
        bare: false,
        locked: false,
        prunable: false
      },
      {
        path: WorktreePath("/home/user/repo-feature1"),
        head: "abc123",
        branch: BranchName("feature1"),
        isPrimary: false,
        bare: false,
        locked: false,
        prunable: false
      },
      {
        path: WorktreePath("/home/user/repo-feature2"),
        head: "def456",
        branch: BranchName("feature2"),
        isPrimary: false,
        bare: false,
        locked: false,
        prunable: false
      }
    ] as Worktree[]),
    worktreeAdd: () => Effect.succeed(WorktreePath("/repo-new-branch")),
    worktreeRemove: () => Effect.succeed(undefined),
    deleteBranch: () => Effect.succeed(undefined),
    checkout: () => Effect.succeed(undefined),
    pull: () => Effect.succeed(undefined),
    rebase: () => Effect.succeed(undefined),
    push: () => Effect.succeed(undefined),
    merge: () => Effect.succeed(undefined),
    mergeSquash: () => Effect.succeed(undefined),
    commit: () => Effect.succeed(undefined),
    hasRemote: () => Effect.succeed(true),
    fetch: () => Effect.succeed(undefined),
    remoteBranchExists: () => Effect.succeed(true),
  }

  const mockTmuxWindows: TmuxWindow[] = [
    { id: "@0", index: 1, name: "\uf418 feature1", active: false },
    { id: "@1", index: 2, name: "main", active: true }
  ]

  const mockTmuxService = {
    listWindows: () => Effect.succeed(mockTmuxWindows)
  }

  const mockMuxRecords: MuxWorktreeEntry[] = [
    {
      id: "wt-1",
      project_id: "proj-1",
      project_path: "/home/user/repo",
      branch: "feature1",
      created_at: "2024-01-01T00:00:00Z",
    },
    {
      id: "wt-2",
      project_id: "proj-1",
      project_path: "/home/user/repo",
      branch: "feature3",
      created_at: "2024-01-01T00:00:00Z",
    }
  ]

  const createMuxService = (overrides: Partial<MuxServiceShape> = {}): MuxServiceShape => ({
    trackWorktree: () => Effect.void,
    find: () => Effect.succeed(null),
    listAll: () => Effect.succeed([]),
    listByProject: () => Effect.succeed(mockMuxRecords),
    removeWorktree: () => Effect.void,
    ...overrides,
  } as any)

  test("lists worktrees for current repo (table format)", async () => {
    const capture = captureStdout()

    const ctx = Context.empty().pipe(
      Context.add(GitService, mockGitService as any),
      Context.add(TmuxService, mockTmuxService as any),
      Context.add(MuxService, createMuxService() as any)
    )

    const result = listHandler({
      group: "mux",
      command: "list",
      flags: { all: false, json: false },
      args: {},
      raw: []
    })

    await Effect.runPromise(result.pipe(Effect.provide(ctx)))

    const output = capture.getOutput()
    capture.restore()

    expect(output).toContain("Branch")
    expect(output).toContain("Path")
    expect(output).toContain("Window")
    expect(output).toContain("feature1")
    expect(output).toContain("feature2")
    expect(output).toContain("feature3")
    expect(output).toContain("open")      // feature1 has tmux window
    expect(output).toContain("closed")    // feature2 has no tmux window
  })

  test("lists worktrees for current repo (JSON format)", async () => {
    const capture = captureStdout()

    const ctx = Context.empty().pipe(
      Context.add(GitService, mockGitService as any),
      Context.add(TmuxService, mockTmuxService as any),
      Context.add(MuxService, createMuxService() as any)
    )

    const result = listHandler({
      group: "mux",
      command: "list",
      flags: { all: false, json: true },
      args: {},
      raw: []
    })

    await Effect.runPromise(result.pipe(Effect.provide(ctx)))

    const output = capture.getOutput()
    capture.restore()

    const parsed = JSON.parse(output)
    expect(Array.isArray(parsed)).toBe(true)
    expect(parsed.some((entry: any) => entry.branch === "feature1")).toBe(true)
    expect(parsed.some((entry: any) => entry.branch === "feature2")).toBe(true)
    expect(parsed.some((entry: any) => entry.branch === "feature3")).toBe(true)

    const feature1 = parsed.find((entry: any) => entry.branch === "feature1")
    expect(feature1.window).toBe("open")
    expect(feature1.repo).toBeUndefined() // not in --all mode
  })

  test("lists worktrees across all repos with --all flag", async () => {
    const capture = captureStdout()

    const mockAllRecords: MuxWorktreeEntry[] = [
      ...mockMuxRecords,
      {
        id: "wt-3",
        project_id: "proj-2",
        project_path: "/home/user/other-repo",
        branch: "main",
        created_at: "2024-01-01T00:00:00Z",
      }
    ]

    const ctx = Context.empty().pipe(
      Context.add(GitService, mockGitService as any),
      Context.add(TmuxService, mockTmuxService as any),
      Context.add(MuxService, createMuxService({
        listAll: () => Effect.succeed(mockAllRecords),
      }) as any)
    )

    const result = listHandler({
      group: "mux",
      command: "list",
      flags: { all: true, json: false },
      args: {},
      raw: []
    })

    await Effect.runPromise(result.pipe(Effect.provide(ctx)))

    const output = capture.getOutput()
    capture.restore()

    expect(output).toContain("Repo")  // Additional column in --all mode
    expect(output).toContain("/home/user/repo")
    expect(output).toContain("/home/user/other-repo")
  })

  test("handles empty worktree list", async () => {
    const capture = captureStdout()

    const mockEmptyGitService = {
      repoRoot: () => Effect.succeed(WorktreePath("/home/user/empty-repo")),
      projectDir: () => Effect.succeed(ProjectPath("/home/user/empty-repo")),
      commonDir: () => Effect.succeed(GitCommonPath("/home/user/empty-repo/.git")),
      primaryWorktreeDir: () => Effect.succeed(WorktreePath("/home/user/empty-repo")),
      currentBranch: () => Effect.succeed(BranchName("main")),
      isWorktree: () => Effect.succeed(null),
      isDirty: () => Effect.succeed(false),
      getProjectConfig: mockGetProjectConfig({ projectPath: ProjectPath("/home/user/repo") }),
        worktreeList: () => Effect.succeed([{
        path: WorktreePath("/home/user/empty-repo"),
        head: "main",
        branch: BranchName("main"),
        isPrimary: true,
        bare: false,
        locked: false,
        prunable: false
      }] as Worktree[]),
      worktreeAdd: () => Effect.succeed(WorktreePath("/repo-new-branch")),
      worktreeRemove: () => Effect.succeed(undefined),
      deleteBranch: () => Effect.succeed(undefined),
      checkout: () => Effect.succeed(undefined),
      pull: () => Effect.succeed(undefined),
      rebase: () => Effect.succeed(undefined),
      push: () => Effect.succeed(undefined),
      merge: () => Effect.succeed(undefined),
      mergeSquash: () => Effect.succeed(undefined),
      commit: () => Effect.succeed(undefined),
      hasRemote: () => Effect.succeed(true),
      fetch: () => Effect.succeed(undefined),
      remoteBranchExists: () => Effect.succeed(true),
    }

    const ctx = Context.empty().pipe(
      Context.add(GitService, mockEmptyGitService as any),
      Context.add(TmuxService, mockTmuxService as any),
      Context.add(MuxService, createMuxService({
        listByProject: () => Effect.succeed([]),
      }) as any)
    )

    const result = listHandler({
      group: "mux",
      command: "list",
      flags: { all: false, json: false },
      args: {},
      raw: []
    })

    await Effect.runPromise(result.pipe(Effect.provide(ctx)))

    const output = capture.getOutput()
    capture.restore()

    // Should still show headers but no data rows
    expect(output).toContain("Branch")
    expect(output).toContain("Path")
  })
})
