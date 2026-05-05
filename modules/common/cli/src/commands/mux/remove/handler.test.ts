import { describe, expect, it, mock } from "bun:test"
import { Effect, Exit, Option } from "effect"
import type { Parsed } from "./command"
import { removeHandler } from "./handler"
import { makeTestLogger, SilentLogger } from "../../../lib/test/logger"
import { GitService, type Worktree, WorktreePath, BranchName, GitCommonPath, ProjectPath } from "../../../services/Git"
import { mockGetProjectConfig } from "../../../services/Git/public/get-project-config.mock"
import { MuxService, type MuxServiceShape, WorktreeId } from "../../../services/Mux"
import { ProjectId } from "../../../services/Git"

const createGitService = (overrides = {}) => GitService.of({
  isWorktree: () => Effect.succeed(Option.none()),
  currentBranch: (_cwd: WorktreePath) => Effect.succeed(BranchName("main")),
  repoRoot: (_path) => Effect.succeed(WorktreePath("/repo")),
  worktreeList: (_gitCommonDir: GitCommonPath) => Effect.succeed<readonly Worktree[]>([
    { path: WorktreePath("/repo/../feature-branch"), head: "abcdef", branch: BranchName("feature-branch"), isPrimary: false, bare: false, locked: false, prunable: false }
  ]),
  isDirty: (_path: WorktreePath) => Effect.succeed(false),
  worktreeRemove: (_worktreePath: WorktreePath, _opts?: { force?: boolean }) => Effect.succeed(undefined),
  worktreeAdd: (_branch: BranchName, _gitCommonDir: GitCommonPath, _opts?: { path?: string; create?: boolean }) => Effect.succeed(WorktreePath("/repo")),
  checkout: (_branch: BranchName, _worktreePath: WorktreePath) => Effect.succeed(undefined),
  pull: (_worktreePath: WorktreePath, _opts?: { rebase?: boolean }) => Effect.succeed(undefined),
  rebase: (_onto: BranchName, _worktreePath: WorktreePath) => Effect.succeed(undefined),
  push: (_worktreePath: WorktreePath) => Effect.succeed(undefined),
  commonDir: (_cwd: any) => Effect.succeed(GitCommonPath("/repo/.git")),
  projectDir: (_cwd: any) => Effect.succeed(ProjectPath("/repo")),
  primaryWorktreeDir: (_cwd: any) => Effect.succeed(WorktreePath("/repo")),
  deleteBranch: (_branch: BranchName, _gitCommonDir: GitCommonPath, _opts?: any) => Effect.succeed(undefined),
  merge: (_branch: BranchName, _worktreePath: WorktreePath) => Effect.succeed(undefined),
  mergeSquash: (_branch: BranchName, _worktreePath: WorktreePath) => Effect.succeed(undefined),
  commit: (_worktreePath: WorktreePath, _message?: string) => Effect.succeed(undefined),
  getProjectConfig: mockGetProjectConfig({ projectPath: ProjectPath("/repo") }),
  hasRemote: (_remote: string, _gitCommonDir: GitCommonPath) => Effect.succeed(true),
  fetch: (_remote: string, _gitCommonDir: GitCommonPath) => Effect.succeed(undefined),
  remoteBranchExists: (_remote: string, _branch: BranchName, _gitCommonDir: GitCommonPath) => Effect.succeed(true),
  ...overrides
})

const MOCK_ENTRY = {
  id: WorktreeId("00000000-0000-0000-0000-000000000001"),
  project_id: ProjectId(crypto.randomUUID()),
  project_path: ProjectPath("/repo"),
  path: WorktreePath("/repo/../feature-branch"),
  branch: BranchName("feature-branch"),
  created_at: "2025-01-01",
}

const createMuxService = (overrides: Partial<MuxServiceShape> = {}) => MuxService.of({
  trackWorktree: () => Effect.void,
  find: () => Effect.succeed(MOCK_ENTRY),
  getWorktreeById: () => Effect.succeed(Option.some(MOCK_ENTRY)),
  getWorktreeFromBranch: () => Effect.succeed(Option.some(MOCK_ENTRY)),
  getWorktreeFromPath: () => Effect.succeed(Option.some(MOCK_ENTRY)),
  listAll: () => Effect.succeed([]),
  listByProject: () => Effect.succeed([]),
  removeWorktree: () => Effect.succeed({ windowClosed: true }),
  ...overrides,
} as any)

const createParsedCommand = (flags: Partial<Record<string, boolean | string>> = {}): Parsed => ({
  group: "mux",
  command: "remove",
  flags: { force: false, branch: undefined, id: undefined, path: undefined, ...flags } as Parsed["flags"],
  args: {} as Parsed["args"],
  raw: []
})

describe.serial("removeHandler", () => {

  it("removes worktree by --branch and delegates cleanup to service", async () => {
    const removeSpy = mock(() => Effect.succeed({ windowClosed: true }))
    const getWorktreeFromBranchSpy = mock(() => Effect.succeed(Option.some(MOCK_ENTRY)))
    const { messages, layer } = makeTestLogger()

    const git = createGitService()
    const mux = createMuxService({ removeWorktree: removeSpy, getWorktreeFromBranch: getWorktreeFromBranchSpy })

    const parsed = createParsedCommand({ branch: "feature-branch" })
    await Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(layer),
      )
    )

    expect(getWorktreeFromBranchSpy).toHaveBeenCalledWith("/repo", "feature-branch")
    expect(removeSpy).toHaveBeenCalledWith("00000000-0000-0000-0000-000000000001")
    expect(messages).toContainEqual(expect.stringContaining("Removed worktree 'feature-branch' and closed tmux window"))
  })

  it("removes worktree by --id", async () => {
    const removeSpy = mock(() => Effect.succeed({ windowClosed: true }))
    const getWorktreeByIdSpy = mock(() => Effect.succeed(Option.some(MOCK_ENTRY)))
    const { messages, layer } = makeTestLogger()

    const git = createGitService()
    const mux = createMuxService({ removeWorktree: removeSpy, getWorktreeById: getWorktreeByIdSpy })

    const parsed = createParsedCommand({ id: "00000000-0000-0000-0000-000000000001" })
    await Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(layer),
      )
    )

    expect(getWorktreeByIdSpy).toHaveBeenCalledWith("00000000-0000-0000-0000-000000000001")
    expect(removeSpy).toHaveBeenCalledWith("00000000-0000-0000-0000-000000000001")
    expect(messages).toContainEqual(expect.stringContaining("Removed worktree 'feature-branch' and closed tmux window"))
  })

  it("errors when --id finds no DB entry", async () => {
    const getWorktreeByIdSpy = mock(() => Effect.succeed(Option.none()))

    const git = createGitService()
    const mux = createMuxService({ getWorktreeById: getWorktreeByIdSpy })

    const parsed = createParsedCommand({ id: "00000000-0000-0000-0000-000000000099" })
    const result = Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(SilentLogger),
      )
    )

    // eslint-disable-next-line @typescript-eslint/await-thenable, @typescript-eslint/no-confusing-void-expression -- bun:test .rejects.toThrow() is async
    await expect(result).rejects.toThrow("No worktree found with id")
  })

  it("removes worktree by --path", async () => {
    const removeSpy = mock(() => Effect.succeed({ windowClosed: true }))
    const getWorktreeFromPathSpy = mock(() => Effect.succeed(Option.some(MOCK_ENTRY)))
    const { messages, layer } = makeTestLogger()

    const git = createGitService()
    const mux = createMuxService({ removeWorktree: removeSpy, getWorktreeFromPath: getWorktreeFromPathSpy })

    const parsed = createParsedCommand({ path: "/repo/../feature-branch" })
    await Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(layer),
      )
    )

    expect(getWorktreeFromPathSpy).toHaveBeenCalledWith("/repo/../feature-branch")
    expect(removeSpy).toHaveBeenCalledWith("00000000-0000-0000-0000-000000000001")
    expect(messages).toContainEqual(expect.stringContaining("Removed worktree 'feature-branch'"))
  })

  it("errors when --path finds no matching worktree", async () => {
    const git = createGitService()
    const mux = createMuxService({ getWorktreeFromPath: () => Effect.succeed(Option.none()) })

    const parsed = createParsedCommand({ path: "/nonexistent/path" })
    const result = Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(SilentLogger),
      )
    )

    // eslint-disable-next-line @typescript-eslint/await-thenable, @typescript-eslint/no-confusing-void-expression -- bun:test .rejects.toThrow() is async
    await expect(result).rejects.toThrow("No worktree found at path")
  })


  it("logs without tmux message when windowClosed is false", async () => {
    const removeSpy = mock(() => Effect.succeed({ windowClosed: false }))
    const { messages, layer } = makeTestLogger()

    const git = createGitService()
    const mux = createMuxService({ removeWorktree: removeSpy })

    const parsed = createParsedCommand({ branch: "feature-branch" })
    await Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(layer),
      )
    )

    expect(removeSpy).toHaveBeenCalledWith("00000000-0000-0000-0000-000000000001")
    expect(messages).toContainEqual(expect.stringContaining("Removed worktree 'feature-branch'"))
    const successMsg = messages.find(m => m.includes("Removed worktree 'feature-branch'"))
    expect(successMsg).not.toContain("closed tmux window")
  })

  it("errors when on main with no flag specified", async () => {
    const git = createGitService()
    const mux = createMuxService()

    const parsed = createParsedCommand() // No flags
    const result = Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(SilentLogger),
      )
    )

    // eslint-disable-next-line @typescript-eslint/await-thenable, @typescript-eslint/no-confusing-void-expression -- bun:test .rejects.toThrow() is async
    await expect(result).rejects.toThrow("Specify --branch, --id, or --path, or run from inside a worktree")
  })

  it("uses current worktree when in worktree and no flag provided", async () => {
    const removeSpy = mock(() => Effect.succeed({ windowClosed: false }))
    const getWorktreeFromPathSpy = mock(() => Effect.succeed(Option.some(MOCK_ENTRY)))

    const git = createGitService({
      isWorktree: () => Effect.succeed(Option.some(WorktreePath("/repo/../feature-branch"))),
    })
    const mux = createMuxService({ removeWorktree: removeSpy, getWorktreeFromPath: getWorktreeFromPathSpy })

    const parsed = createParsedCommand() // No flags
    await Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(SilentLogger),
      )
    )

    expect(getWorktreeFromPathSpy).toHaveBeenCalled()
    expect(removeSpy).toHaveBeenCalled()
  })

  it("errors when worktree not found by --branch", async () => {
    const git = createGitService()
    const mux = createMuxService({ getWorktreeFromBranch: () => Effect.succeed(Option.none()) })

    const parsed = createParsedCommand({ branch: "nonexistent-branch" })
    const result = Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(SilentLogger),
      )
    )

    // eslint-disable-next-line @typescript-eslint/await-thenable, @typescript-eslint/no-confusing-void-expression -- bun:test .rejects.toThrow() is async
    await expect(result).rejects.toThrow("Worktree for branch 'nonexistent-branch' not found")
  })

  it("skips prompt with --force flag when worktree is dirty", async () => {
    const removeSpy = mock(() => Effect.succeed({ windowClosed: false }))

    const git = createGitService({
      isDirty: () => Effect.succeed(true), // Worktree is dirty
    })
    const mux = createMuxService({ removeWorktree: removeSpy })

    const parsed = createParsedCommand({ branch: "feature-branch", force: true })

    await Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(SilentLogger),
      )
    )

    expect(removeSpy).toHaveBeenCalled()
  })

  it("errors on dirty worktree without --force", async () => {
    const git = createGitService({ isDirty: () => Effect.succeed(true) })
    const mux = createMuxService()

    const parsed = createParsedCommand({ branch: "feature-branch" })
    const exit = await Effect.runPromiseExit(
      removeHandler(parsed).pipe(
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(SilentLogger),
      )
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit)) {
      const errorMessage = String(exit.cause)
      expect(errorMessage).toContain("uncommitted changes")
    }
  })
})
