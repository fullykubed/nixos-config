import { describe, expect, it, mock } from "bun:test"
import { Effect, Exit, Option } from "effect"
import type { Parsed } from "./command"
import { removeHandler } from "./handler"
import { makeTestLogger, SilentLogger } from "../../../lib/test-logger"
import { TmuxService } from "../../../services/Tmux"
import { GitService, type Worktree, WorktreePath, BranchName, GitCommonPath, ProjectPath } from "../../../services/Git"
import { mockGetProjectConfig } from "../../../services/Git/public/get-project-config.mock"
import { MuxService, type MuxServiceShape } from "../../../services/Mux"

// Helper to create mock services using Service.of()
const createTmuxService = (overrides = {}) => TmuxService.of({
  isInsideTmux: () => Effect.succeed(true),
  currentSession: () => Effect.succeed("test-session"),
  listWindows: () => Effect.succeed([
    { id: "@0", index: 1, name: "main", active: false },
    { id: "@1", index: 2, name: "\uf418 feature-branch", active: false }
  ]),
  switchWindow: (_name: string) => Effect.succeed(undefined),
  killWindow: (_name: string) => Effect.succeed(undefined),
  createWindow: (_opts: any) => Effect.succeed("@0"),
  splitPane: (_opts: any) => Effect.succeed(undefined),
  sendKeys: (_target: string, _keys: string) => Effect.succeed(undefined),
  selectPane: (_index: number) => Effect.succeed(undefined),
  findWindow: (_namePattern: string) => Effect.succeed(null),
  setWindowOption: (_target: string, _key: string, _value: string) => Effect.succeed(undefined),
  setPaneOption: (_target: string, _key: string, _value: string) => Effect.succeed(undefined),
  setSessionOption: (_key: string, _value: string, _session?: string) => Effect.succeed(undefined),
  ensureSession: (_name: string) => Effect.succeed(undefined),
  sessionExists: (_name: string) => Effect.succeed(true),
  renameSession: (_oldName: string, _newName: string) => Effect.succeed(undefined),
  ...overrides
})

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

const createMuxService = (overrides: Partial<MuxServiceShape> = {}) => MuxService.of({
  trackWorktree: () => Effect.void,
  find: () => Effect.succeed({ id: "00000000-0000-0000-0000-000000000001", project_id: "proj-1", project_path: "/repo/.git", branch: "feature-branch", created_at: "2025-01-01" }),
  listAll: () => Effect.succeed([]),
  listByProject: () => Effect.succeed([]),
  removeWorktree: () => Effect.succeed({ windowClosed: true }),
  ...overrides,
} as any)

const createParsedCommand = (branch?: string, flags: Record<string, boolean | string> = {}): Parsed => ({
  group: "mux",
  command: "remove",
  flags: { force: false, ...flags } as Parsed["flags"],
  args: { branch: branch ? BranchName(branch) : undefined } as Parsed["args"],
  raw: []
})

describe.serial("removeHandler", () => {

  it("removes worktree and delegates cleanup to service", async () => {
    const removeSpy = mock(() => Effect.succeed({ windowClosed: true }))
    const findSpy = mock(() => Effect.succeed({ id: "00000000-0000-0000-0000-000000000001", project_id: "proj-42", project_path: "/repo/.git", branch: "feature-branch", created_at: "2025-01-01" }))
    const { messages, layer } = makeTestLogger()

    const tmux = createTmuxService()
    const git = createGitService()
    const mux = createMuxService({ removeWorktree: removeSpy, find: findSpy })

    const parsed = createParsedCommand("feature-branch")
    await Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(TmuxService, tmux),
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(layer),
      )
    )

    expect(findSpy).toHaveBeenCalledWith("/repo/.git", "feature-branch")
    expect(removeSpy).toHaveBeenCalledWith("00000000-0000-0000-0000-000000000001")
    expect(messages).toContainEqual(expect.stringContaining("Removed worktree 'feature-branch' and closed tmux window"))
  })

  it("logs without tmux message when windowClosed is false", async () => {
    const removeSpy = mock(() => Effect.succeed({ windowClosed: false }))
    const { messages, layer } = makeTestLogger()

    const tmux = createTmuxService()
    const git = createGitService()
    const mux = createMuxService({ removeWorktree: removeSpy, find: () => Effect.succeed(null) })

    const parsed = createParsedCommand("feature-branch")
    await Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(TmuxService, tmux),
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(layer),
      )
    )

    // find returned null, so removeWorktree is skipped
    expect(removeSpy).not.toHaveBeenCalled()
    expect(messages).toContainEqual(expect.stringContaining("Removed worktree 'feature-branch'"))
    // Should NOT contain "closed tmux window"
    const successMsg = messages.find(m => m.includes("Removed worktree 'feature-branch'"))
    expect(successMsg).not.toContain("closed tmux window")
  })

  it("errors when not inside tmux", async () => {
    const tmux = createTmuxService({ isInsideTmux: () => Effect.succeed(false) })
    const git = createGitService()
    const mux = createMuxService()

    const parsed = createParsedCommand("feature-branch")
    const result = Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(TmuxService, tmux),
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(SilentLogger),
      )
    )

    // eslint-disable-next-line @typescript-eslint/await-thenable, @typescript-eslint/no-confusing-void-expression -- bun:test .rejects.toThrow() is async
    await expect(result).rejects.toThrow("Must be inside a tmux session")
  })

  it("errors when on main with no branch arg", async () => {
    const tmux = createTmuxService()
    const git = createGitService({ isWorktree: () => Effect.succeed(false) })
    const mux = createMuxService()

    const parsed = createParsedCommand() // No branch argument
    const result = Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(TmuxService, tmux),
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(SilentLogger),
      )
    )

    // eslint-disable-next-line @typescript-eslint/await-thenable, @typescript-eslint/no-confusing-void-expression -- bun:test .rejects.toThrow() is async
    await expect(result).rejects.toThrow("Specify a branch name or run from inside a worktree")
  })

  it("uses current branch when in worktree and no arg provided", async () => {
    const removeSpy = mock(() => Effect.succeed({ windowClosed: false }))

    const tmux = createTmuxService()
    const git = createGitService({
      isWorktree: () => Effect.succeed(Option.some(WorktreePath("/repo/../feature-branch"))),
      currentBranch: () => Effect.succeed(BranchName("feature-branch")),
    })
    const mux = createMuxService({ removeWorktree: removeSpy })

    const parsed = createParsedCommand() // No branch argument
    await Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(TmuxService, tmux),
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(SilentLogger),
      )
    )

    expect(removeSpy).toHaveBeenCalled()
  })

  it("errors when worktree not found", async () => {
    const tmux = createTmuxService()
    const git = createGitService({
      worktreeList: () => Effect.succeed([]) // No worktrees
    })
    const mux = createMuxService()

    const parsed = createParsedCommand("nonexistent-branch")
    const result = Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(TmuxService, tmux),
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

    const tmux = createTmuxService()
    const git = createGitService({
      isDirty: () => Effect.succeed(true), // Worktree is dirty
    })
    const mux = createMuxService({ removeWorktree: removeSpy })

    const parsed = createParsedCommand("feature-branch", { force: true })

    await Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(TmuxService, tmux),
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(SilentLogger),
      )
    )

    // With --force, removeWorktree should be called (via find returning default mock entry)
    expect(removeSpy).toHaveBeenCalled()
  })

  it("prompts on dirty worktree without --force (interactive)", async () => {
    const removeSpy = mock(() => Effect.succeed({ windowClosed: false }))
    const writeSpy = mock(() => { /* noop */ })

    // Mock TTY and stdin
    const mockProcess = {
      stdin: {
        isTTY: true,
        resume: mock(() => { /* noop */ }),
        setEncoding: mock(() => { /* noop */ }),
        once: mock((_event: string, callback: (data: string) => void) => {
          // Simulate user typing 'y'
          setTimeout(() => { callback("y\n") }, 0)
        }),
        pause: mock(() => { /* noop */ })
      },
      stdout: {
        write: writeSpy
      }
    }

    // Replace global process for this test
    const originalProcess = global.process
    global.process = { ...originalProcess, ...mockProcess } as any

    const tmux = createTmuxService()
    const git = createGitService({
      isDirty: () => Effect.succeed(true), // Worktree is dirty
    })
    const mux = createMuxService({ removeWorktree: removeSpy })

    const parsed = createParsedCommand("feature-branch")

    await Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(TmuxService, tmux),
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(SilentLogger),
      )
    )

    expect(writeSpy).toHaveBeenCalledWith("Worktree has uncommitted changes. Remove? [y/N] ")
    expect(removeSpy).toHaveBeenCalled()

    // Restore original process
    global.process = originalProcess
  })

  it("cancels removal when user says no (interactive)", async () => {
    const removeSpy = mock(() => Effect.succeed({ windowClosed: false }))
    const { messages, layer } = makeTestLogger()

    // Mock TTY and stdin
    const mockProcess = {
      stdin: {
        isTTY: true,
        resume: mock(() => { /* noop */ }),
        setEncoding: mock(() => { /* noop */ }),
        once: mock((_event: string, callback: (data: string) => void) => {
          // Simulate user typing 'n'
          setTimeout(() => { callback("n\n") }, 0)
        }),
        pause: mock(() => { /* noop */ })
      },
      stdout: {
        write: mock(() => { /* noop */ })
      }
    }

    const originalProcess = global.process
    global.process = { ...originalProcess, ...mockProcess } as any

    const tmux = createTmuxService()
    const git = createGitService({
      isDirty: () => Effect.succeed(true) // Worktree is dirty
    })
    const mux = createMuxService({ removeWorktree: removeSpy })

    const parsed = createParsedCommand("feature-branch")

    await Effect.runPromise(
      removeHandler(parsed).pipe(
        Effect.provideService(TmuxService, tmux),
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(layer),
      )
    )

    expect(messages).toContainEqual(expect.stringContaining("Removal cancelled."))
    expect(removeSpy).not.toHaveBeenCalled()

    global.process = originalProcess
  })

  it("errors on dirty worktree in non-interactive mode without --force", async () => {
    // Mock non-TTY
    const mockProcess = {
      stdin: {
        isTTY: false
      }
    }

    const originalProcess = global.process
    global.process = { ...originalProcess, ...mockProcess } as any

    const tmux = createTmuxService()
    const git = createGitService({ isDirty: () => Effect.succeed(true) }) // Worktree is dirty
    const mux = createMuxService()

    const parsed = createParsedCommand("feature-branch")
    const exit = await Effect.runPromiseExit(
      removeHandler(parsed).pipe(
        Effect.provideService(TmuxService, tmux),
        Effect.provideService(GitService, git),
        Effect.provideService(MuxService, mux),
        Effect.provide(SilentLogger),
      )
    )

    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit)) {
      // Check that it's an error about uncommitted changes
      const errorMessage = String(exit.cause)
      expect(errorMessage).toContain("uncommitted changes")
    }

    global.process = originalProcess
  })
})
