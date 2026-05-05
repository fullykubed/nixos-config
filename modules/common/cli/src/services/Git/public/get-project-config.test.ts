import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { FileSystem, Path } from "@effect/platform"
import { ShellService } from "../../Shell"
import { getProjectConfig } from "./get-project-config"
import { ProjectConfigParseError } from "../errors"
import { DEFAULT_CONFIG } from "../config-defaults"
import { ProjectPath, ProjectId, WorktreePath } from "../types"

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return (cause.error as { _tag?: string })._tag
  return undefined
}

function extractFailure(exit: Exit.Exit<unknown, unknown>): unknown {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return cause.error
  return undefined
}

const mockPath = Path.Path.of({
  join: (...paths: string[]) => paths.join("/"),
  resolve: (...paths: string[]) => paths.reduce((a, b) => {
    if (b === "..") return a.replace(/\/[^/]+$/, "")
    return b.startsWith("/") ? b : `${a}/${b}`
  }),
  basename: (p: string) => p.split("/").pop() ?? "",
} as never)

const mockShell = {
  exec: () => Effect.succeed({ stdout: "/test/repo/.git", stderr: "", exitCode: 0 }),
  execJson: () => Effect.succeed({}) as any,
  execLines: () => Effect.succeed([]) as any,
}

const provide = (files: Record<string, string | null>) =>
  Effect.provide(
    Context.empty().pipe(
      Context.add(FileSystem.FileSystem, FileSystem.FileSystem.of({
        exists: (path: string) => Effect.succeed(files[path] !== undefined),
        readFileString: (path: string) =>
          files[path] != null
            ? Effect.succeed(files[path])
            : Effect.fail(new Error("File not readable")),
        writeFileString: (path: string, content: string) => Effect.sync(() => { files[path] = content }),
        stat: () => Effect.succeed(null) as any,
      } as never)),
      Context.add(Path.Path, mockPath),
      Context.add(ShellService, ShellService.of(mockShell)),
    )
  )

describe("getProjectConfig", () => {
  it("returns DEFAULT_CONFIG when project.json doesn't exist in common dir", async () => {
    const result = await Effect.runPromise(
      getProjectConfig(ProjectPath("/test/repo")).pipe(provide({}))
    )

    expect(result.primary_branch).toBe(DEFAULT_CONFIG.primary_branch)
    expect(result.worktree).toEqual(DEFAULT_CONFIG.worktree)
    expect(result.projectPath).toBe(ProjectPath("/test/repo"))
    expect(result.projectId).toMatch(/^[0-9a-f-]{36}$/)
  })

  it("reads project.json from git common dir", async () => {
    const config = {
      primary_branch: "develop",
      worktree: {
        merge_strategy: "squash",
        files: { copy: [".env", "config.json"] }
      }
    }

    const result = await Effect.runPromise(
      getProjectConfig(ProjectPath("/test/repo")).pipe(provide({
        "/test/repo/.git/project.json": JSON.stringify(config, null, 2)
      }))
    )

    expect(result.primary_branch).toBe("develop")
    expect(result.worktree.merge_strategy).toBe("squash")
    expect(result.worktree.files.copy).toEqual([".env", "config.json"])
    expect(result.worktree.panes).toEqual(DEFAULT_CONFIG.worktree.panes)
    expect(result.worktree.post_create).toEqual(DEFAULT_CONFIG.worktree.post_create)
    expect(result.worktree.pre_merge).toEqual(DEFAULT_CONFIG.worktree.pre_merge)
  })

  it("returns DEFAULT_CONFIG when project.json exists but is unreadable", async () => {
    const result = await Effect.runPromise(
      getProjectConfig(ProjectPath("/test/repo")).pipe(provide({
        "/test/repo/.git/project.json": null
      }))
    )

    expect(result.primary_branch).toBe(DEFAULT_CONFIG.primary_branch)
    expect(result.worktree).toEqual(DEFAULT_CONFIG.worktree)
  })

  it("returns ProjectConfigParseError for invalid JSON", async () => {
    const exit = await Effect.runPromiseExit(
      getProjectConfig(ProjectPath("/test/repo")).pipe(provide({
        "/test/repo/.git/project.json": "{ invalid json }"
      }))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("ProjectConfigParseError")

    const error = extractFailure(exit) as ProjectConfigParseError
    expect(error.path).toMatch(/project\.json$/)
    expect(error.message).toContain("JSON")
  })

  it("returns defaults for worktree config when worktree section is missing", async () => {
    const config = { primary_branch: "staging" }

    const result = await Effect.runPromise(
      getProjectConfig(ProjectPath("/test/repo")).pipe(provide({
        "/test/repo/.git/project.json": JSON.stringify(config, null, 2)
      }))
    )

    expect(result.primary_branch).toBe("staging")
    expect(result.worktree).toEqual(DEFAULT_CONFIG.worktree)
  })

  it("merges partial worktree section with defaults", async () => {
    const config = {
      worktree: {
        merge_strategy: "merge",
        post_create: ["echo 'setup complete'"]
      }
    }

    const result = await Effect.runPromise(
      getProjectConfig(ProjectPath("/test/repo")).pipe(provide({
        "/test/repo/.git/project.json": JSON.stringify(config, null, 2)
      }))
    )

    expect(result.primary_branch).toBe(DEFAULT_CONFIG.primary_branch)
    expect(result.worktree.merge_strategy).toBe("merge")
    expect(result.worktree.post_create).toEqual(["echo 'setup complete'"])
    expect(result.worktree.panes).toEqual(DEFAULT_CONFIG.worktree.panes)
    expect(result.worktree.files.copy).toEqual(DEFAULT_CONFIG.worktree.files.copy)
    expect(result.worktree.pre_merge).toEqual(DEFAULT_CONFIG.worktree.pre_merge)
  })

  it("handles empty project.json file", async () => {
    const result = await Effect.runPromise(
      getProjectConfig(ProjectPath("/test/repo")).pipe(provide({
        "/test/repo/.git/project.json": "{}"
      }))
    )

    expect(result.primary_branch).toBe(DEFAULT_CONFIG.primary_branch)
    expect(result.worktree).toEqual(DEFAULT_CONFIG.worktree)
  })

  it("returns ProjectConfigParseError for invalid merge_strategy", async () => {
    const config = {
      worktree: { merge_strategy: "invalid_strategy" }
    }

    const exit = await Effect.runPromiseExit(
      getProjectConfig(ProjectPath("/test/repo")).pipe(provide({
        "/test/repo/.git/project.json": JSON.stringify(config, null, 2)
      }))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("ProjectConfigParseError")
  })

  it("returns ProjectConfigParseError for wrong-type field values", async () => {
    const config = {
      worktree: { files: { copy: "not_an_array" } }
    }

    const exit = await Effect.runPromiseExit(
      getProjectConfig(ProjectPath("/test/repo")).pipe(provide({
        "/test/repo/.git/project.json": JSON.stringify(config, null, 2)
      }))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("ProjectConfigParseError")
  })

  it("merges worktree-local config over common dir config", async () => {
    const result = await Effect.runPromise(
      getProjectConfig(WorktreePath("/test/worktree")).pipe(provide({
        "/test/repo/.git/project.json": JSON.stringify({ primary_branch: "develop", name: "my-project" }),
        "/test/worktree/project.json": JSON.stringify({ primary_branch: "from-worktree" }),
      }))
    )

    expect(result.primary_branch).toBe("from-worktree")
    expect(result.name).toBe("my-project")
    expect(result.projectPath).toBe(ProjectPath("/test/repo"))
  })

  it("does not read worktree overlay when path is the project root", async () => {
    const result = await Effect.runPromise(
      getProjectConfig(ProjectPath("/test/repo")).pipe(provide({
        "/test/repo/.git/project.json": JSON.stringify({ primary_branch: "develop" }),
        "/test/repo/project.json": JSON.stringify({ primary_branch: "should-be-ignored" }),
      }))
    )

    expect(result.primary_branch).toBe("develop")
  })

  it("reads existing project.id from common dir", async () => {
    const result = await Effect.runPromise(
      getProjectConfig(ProjectPath("/test/repo")).pipe(provide({
        "/test/repo/.git/project.id": "550e8400-e29b-41d4-a716-446655440000",
      }))
    )

    expect(result.projectId).toBe(ProjectId("550e8400-e29b-41d4-a716-446655440000"))
  })

  it("generates and persists project.id when missing", async () => {
    const files: Record<string, string | null> = {}
    const result = await Effect.runPromise(
      getProjectConfig(ProjectPath("/test/repo")).pipe(provide(files))
    )

    expect(result.projectId).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
    expect(files["/test/repo/.git/project.id"]).toBe(result.projectId + "\n")
  })

  it("regenerates project.id when file contains invalid content", async () => {
    const files: Record<string, string | null> = {
      "/test/repo/.git/project.id": "not-a-uuid",
    }
    const result = await Effect.runPromise(
      getProjectConfig(ProjectPath("/test/repo")).pipe(provide(files))
    )

    expect(result.projectId).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
    expect(result.projectId).not.toBe("not-a-uuid")
    expect(files["/test/repo/.git/project.id"]).toBe(result.projectId + "\n")
  })
})
