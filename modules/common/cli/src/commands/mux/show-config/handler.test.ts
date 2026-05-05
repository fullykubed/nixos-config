import { describe, test, expect } from "bun:test"
import { Effect, Context } from "effect"
import { showConfigHandler } from "./handler"
import { GitService, WorktreePath, ProjectPath } from "../../../services/Git"
import { mockGetProjectConfig } from "../../../services/Git/public/get-project-config.mock"

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

describe("showConfigHandler", () => {
  const mockGitService = {
    repoRoot: () => Effect.succeed(WorktreePath("/home/user/repo")),
    projectDir: () => Effect.succeed(ProjectPath("/home/user/repo")),
    getProjectConfig: mockGetProjectConfig({ projectPath: ProjectPath("/home/user/repo") }),
  }

  const ctx = Context.empty().pipe(
    Context.add(GitService, mockGitService as any),
  )

  test("shows config in table format", async () => {
    const capture = captureStdout()

    await Effect.runPromise(
      showConfigHandler({
        group: "mux",
        command: "show-config",
        flags: { json: false },
        args: {},
        raw: []
      }).pipe(Effect.provide(ctx))
    )

    const output = capture.getOutput()
    capture.restore()

    expect(output).toContain("Key")
    expect(output).toContain("Value")
    expect(output).toContain("name")
    expect(output).toContain("repo")
    expect(output).toContain("primary_branch")
    expect(output).toContain("main")
    expect(output).toContain("merge_strategy")
    expect(output).toContain("rebase")
    expect(output).toContain("project_id")
  })

  test("shows config in JSON format", async () => {
    const capture = captureStdout()

    await Effect.runPromise(
      showConfigHandler({
        group: "mux",
        command: "show-config",
        flags: { json: true },
        args: {},
        raw: []
      }).pipe(Effect.provide(ctx))
    )

    const output = capture.getOutput()
    capture.restore()

    const parsed = JSON.parse(output)
    expect(parsed.name).toBe("repo")
    expect(parsed.primary_branch).toBe("main")
    expect(parsed.worktree.merge_strategy).toBe("rebase")
    expect(parsed.projectPath).toBe("/home/user/repo")
    expect(parsed.projectId).toBeDefined()
  })

  test("shows custom config values", async () => {
    const capture = captureStdout()

    const customGitService = {
      ...mockGitService,
      getProjectConfig: mockGetProjectConfig({
        projectPath: ProjectPath("/home/user/my-project"),
        name: "my-project",
        tmux_session: "mp",
        primary_branch: "develop",
        worktree: {
          files: { copy: [".env"], link: ["node_modules"] },
          panes: [{ command: "nvim ." }],
          merge_strategy: "squash" as const,
          post_create: ["bun install"],
          pre_merge: ["bun test"],
        },
      }),
    }

    const customCtx = Context.empty().pipe(
      Context.add(GitService, customGitService as any),
    )

    await Effect.runPromise(
      showConfigHandler({
        group: "mux",
        command: "show-config",
        flags: { json: false },
        args: {},
        raw: []
      }).pipe(Effect.provide(customCtx))
    )

    const output = capture.getOutput()
    capture.restore()

    expect(output).toContain("my-project")
    expect(output).toContain("mp")
    expect(output).toContain("develop")
    expect(output).toContain("squash")
    expect(output).toContain(".env")
    expect(output).toContain("node_modules")
    expect(output).toContain("bun install")
    expect(output).toContain("bun test")
    expect(output).toContain("1 pane(s)")
  })
})
