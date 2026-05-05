import { Effect, Context, Either, Option } from "effect"
import { SilentLogger } from "../../../lib/test-logger"
import { describe, test, expect, mock } from "bun:test"
import { mergeHandler } from "./handler"
import { TmuxService, NotInsideTmuxError } from "../../../services/Tmux"
import type { TmuxServiceShape } from "../../../services/Tmux"
import { GitService, WorktreePath, BranchName, GitUnknownError, ProjectPath, GitCommonPath } from "../../../services/Git"
import { mockGetProjectConfig } from "../../../services/Git/public/get-project-config.mock"
import type { GitServiceShape } from "../../../services/Git"
import { ShellService } from "../../../services/Shell"
import type { ShellServiceShape } from "../../../services/Shell"
import { MuxService, type MuxServiceShape } from "../../../services/Mux"
import type { Parsed } from "./command"

describe("mergeHandler", () => {
  const createParsedCommand = (flags: Record<string, string | boolean> = {}): Parsed => ({
    group: "mux",
    command: "merge",
    args: {},
    flags: {
      ...flags,
      into: "into" in flags && typeof flags.into === "string" ? BranchName(flags.into) : undefined,
    } as Parsed["flags"],
    raw: ["mux", "merge"],
  })

  const mockContext = (overrides: {
    mux?: Partial<MuxServiceShape>
    tmux?: Partial<TmuxServiceShape>
    git?: Partial<GitServiceShape>
    shell?: Partial<ShellServiceShape>
  } = {}) => {
    return Context.empty().pipe(
      Context.add(MuxService, {
        trackWorktree: () => Effect.void,
        find: () => Effect.succeed({ id: "00000000-0000-0000-0000-000000000001", project_id: "proj-1", project_path: "/repo/.git", branch: "feature-branch", created_at: "2025-01-01" }),
        listAll: () => Effect.succeed([]),
        listByProject: () => Effect.succeed([]),
        removeWorktree: () => Effect.succeed({ windowClosed: true }),
        ...overrides.mux,
      } as any),
      Context.add(TmuxService, {
        isInsideTmux: () => Effect.succeed(true),
        listWindows: () => Effect.succeed([
          { id: "@0", index: 1, name: "main", active: false },
          { id: "@1", index: 2, name: "\uf418 feature-branch", active: true }
        ]),
        switchWindow: () => Effect.succeed(undefined),
        killWindow: () => Effect.succeed(undefined),
        ...overrides.tmux,
      } as any),
      Context.add(GitService, {
        isWorktree: () => Effect.succeed(Option.some(WorktreePath("/repo-feature-branch"))),
        repoRoot: () => Effect.succeed(WorktreePath("/repo")),
        projectDir: () => Effect.succeed(ProjectPath("/repo")),
        commonDir: () => Effect.succeed(GitCommonPath("/repo/.git")),
        primaryWorktreeDir: () => Effect.succeed(WorktreePath("/repo")),
        currentBranch: () => Effect.succeed(BranchName("feature-branch")),
        worktreeList: () => Effect.succeed([
          { path: WorktreePath("/repo"), branch: BranchName("main"), isPrimary: true, head: "abc123", bare: false, locked: false, prunable: false },
          { path: WorktreePath("/repo-feature-branch"), branch: BranchName("feature-branch"), isPrimary: false, head: "def456", bare: false, locked: false, prunable: false }
        ]),
        isDirty: () => Effect.succeed(false),
        checkout: () => Effect.succeed(undefined),
        pull: () => Effect.succeed(undefined),
        rebase: () => Effect.succeed(undefined),
        push: () => Effect.succeed(undefined),
        worktreeRemove: () => Effect.succeed(undefined),
        deleteBranch: () => Effect.succeed(undefined),
        merge: () => Effect.succeed(undefined),
        mergeSquash: () => Effect.succeed(undefined),
        commit: () => Effect.succeed(undefined),
        getProjectConfig: mockGetProjectConfig({ projectPath: ProjectPath("/repo") }),
        hasRemote: () => Effect.succeed(true),
        fetch: () => Effect.succeed(undefined),
        remoteBranchExists: () => Effect.succeed(true),
        worktreeAdd: () => Effect.succeed(WorktreePath("/repo-new-branch")),
        ...overrides.git,
      } as any),
      Context.add(ShellService, {
        exec: (cmd: string, args?: readonly string[]) => {
          if (cmd === "sh" && args?.[0] === "-c" && args[1] === "echo 'pre-merge hook'") {
            return Effect.succeed({ stdout: "pre-merge hook\n", stderr: "", exitCode: 0 })
          }
          return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
        },
        ...overrides.shell,
      } as any),
    )
  }

  test("errors when not inside tmux", async () => {
    const ctx = mockContext({
      tmux: { isInsideTmux: () => Effect.succeed(false) }
    })

    const result = await mergeHandler(createParsedCommand()).pipe(
      Effect.provide(ctx),
      Effect.provide(SilentLogger),
      Effect.either,
      Effect.runPromise
    )

    expect(Either.isLeft(result)).toBe(true)
    if (Either.isLeft(result)) {
      expect(result.left).toBeInstanceOf(NotInsideTmuxError)
    }
  })

  test("errors when not in a worktree", async () => {
    const ctx = mockContext({
      git: { isWorktree: () => Effect.succeed(Option.none()) }
    })

    const result = await mergeHandler(createParsedCommand()).pipe(
      Effect.provide(ctx),
      Effect.provide(SilentLogger),
      Effect.either,
      Effect.runPromise
    )

    expect(Either.isLeft(result)).toBe(true)
    if (Either.isLeft(result)) {
      expect(result.left.message).toContain("Must be run from inside a worktree")
    }
  })

  test("errors if worktree has uncommitted changes", async () => {
    const ctx = mockContext({
      git: { isDirty: () => Effect.succeed(true) }
    })

    const result = await mergeHandler(createParsedCommand()).pipe(
      Effect.provide(ctx),
      Effect.provide(SilentLogger),
      Effect.either,
      Effect.runPromise
    )

    expect(Either.isLeft(result)).toBe(true)
    if (Either.isLeft(result)) {
      expect(String(result.left)).toContain("uncommitted changes")
    }
  })

  test("executes rebase strategy correctly", async () => {
    const mockGit = {
      checkout: mock(() => Effect.succeed(undefined)),
      pull: mock(() => Effect.succeed(undefined)),
      rebase: mock(() => Effect.succeed(undefined)),
      push: mock(() => Effect.succeed(undefined)),
    }

    const ctx = mockContext({ git: mockGit })

    await mergeHandler(createParsedCommand()).pipe(
      Effect.provide(ctx),
      Effect.provide(SilentLogger),
      Effect.runPromise
    )

    expect(mockGit.checkout).toHaveBeenCalledWith(BranchName("main"), WorktreePath("/repo"))
    expect(mockGit.pull).toHaveBeenCalledWith(WorktreePath("/repo"), { rebase: true })
    expect(mockGit.rebase).toHaveBeenCalledWith(BranchName("feature-branch"), WorktreePath("/repo"))
    expect(mockGit.push).toHaveBeenCalledWith(WorktreePath("/repo"))
  })

  test("aborts rebase on conflict", async () => {
    const conflictError = new GitUnknownError({ message: "CONFLICT: merge conflict" })
    const mockShell = mock((cmd: string, args?: readonly string[]) => {
      if (cmd === "git" && args?.includes("rebase") && args.includes("--abort")) {
        return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
      }
      return Effect.succeed({ stdout: "", stderr: "", exitCode: 0 })
    })

    const ctx = mockContext({
      git: { rebase: (_onto: BranchName, _worktreePath: WorktreePath) => Effect.fail(conflictError) },
      shell: { exec: mockShell }
    })

    const result = await mergeHandler(createParsedCommand()).pipe(
      Effect.provide(ctx),
      Effect.provide(SilentLogger),
      Effect.either,
      Effect.runPromise
    )

    expect(Either.isLeft(result)).toBe(true)
    if (Either.isLeft(result)) {
      expect(String(result.left)).toContain("CONFLICT")
    }

    // Should have attempted to abort the rebase
    expect(mockShell).toHaveBeenCalledWith("git", ["-C", "/repo", "rebase", "--abort"])
  })

  test("uses --into flag when provided", async () => {
    const mockGit = {
      checkout: mock(() => Effect.succeed(undefined)),
      worktreeList: () => Effect.succeed([
        { path: WorktreePath("/repo"), branch: BranchName("main"), isPrimary: true, head: "abc123", bare: false, locked: false, prunable: false },
        { path: WorktreePath("/repo-develop"), branch: BranchName("develop"), isPrimary: false, head: "bbb222", bare: false, locked: false, prunable: false },
        { path: WorktreePath("/repo-feature-branch"), branch: BranchName("feature-branch"), isPrimary: false, head: "def456", bare: false, locked: false, prunable: false }
      ]),
    }

    const ctx = mockContext({ git: mockGit })

    await mergeHandler(createParsedCommand({ into: "develop" })).pipe(
      Effect.provide(ctx),
      Effect.provide(SilentLogger),
      Effect.runPromise
    )

    expect(mockGit.checkout).toHaveBeenCalledWith("develop", "/repo-develop")
  })

  test("falls back to primary_branch from config when --into not provided", async () => {
    const mockGit = {
      checkout: mock(() => Effect.succeed(undefined)),
    }

    const ctx = mockContext({ git: mockGit })

    await mergeHandler(createParsedCommand()).pipe(
      Effect.provide(ctx),
      Effect.provide(SilentLogger),
      Effect.runPromise
    )

    expect(mockGit.checkout).toHaveBeenCalledWith("main", "/repo")
  })
})
