import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { FileSystem, Path } from "@effect/platform"
import { readConfig } from "./read-config"
import { DEFAULT_CONFIG } from "../config-defaults"
import { ProjectConfigParseError } from "../errors"

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
} as never)

const provide = (configs: Record<string, string | null>) =>
  Effect.provide(
    Context.empty().pipe(
      Context.add(FileSystem.FileSystem, FileSystem.FileSystem.of({
        exists: (path: string) => Effect.succeed(configs[path] !== undefined),
        readFileString: (path: string) =>
          configs[path] !== null
            ? Effect.succeed(configs[path]!)
            : Effect.fail(new Error("File not readable")),
      } as never)),
      Context.add(Path.Path, mockPath),
    )
  )

describe("readConfig", () => {
  it("returns DEFAULT_CONFIG when project.json doesn't exist", async () => {
    const result = await Effect.runPromise(
      readConfig("/test/repo").pipe(provide({}))
    )

    expect(result).toEqual(DEFAULT_CONFIG)
  })

  it("reads project.json from repo root", async () => {
    const config = {
      primary_branch: "develop",
      worktree: {
        merge_strategy: "squash",
        files: { copy: [".env", "config.json"] }
      }
    }

    const result = await Effect.runPromise(
      readConfig("/test/repo").pipe(provide({
        "/test/repo/project.json": JSON.stringify(config, null, 2)
      }))
    )

    expect(result.primary_branch).toBe("develop")
    expect(result.worktree.merge_strategy).toBe("squash")
    expect(result.worktree.files.copy).toEqual([".env", "config.json"])
    expect(result.worktree.panes).toEqual(DEFAULT_CONFIG.worktree.panes)
    expect(result.worktree.post_create).toEqual(DEFAULT_CONFIG.worktree.post_create)
    expect(result.worktree.pre_merge).toEqual(DEFAULT_CONFIG.worktree.pre_merge)
  })

  it("falls back to .bare/project.json when repo root has none", async () => {
    const config = { primary_branch: "trunk" }

    const result = await Effect.runPromise(
      readConfig("/test/repo").pipe(provide({
        "/test/repo/.bare/project.json": JSON.stringify(config)
      }))
    )

    expect(result.primary_branch).toBe("trunk")
    expect(result.worktree).toEqual(DEFAULT_CONFIG.worktree)
  })

  it("prefers repo root over .bare when both exist", async () => {
    const result = await Effect.runPromise(
      readConfig("/test/repo").pipe(provide({
        "/test/repo/project.json": JSON.stringify({ primary_branch: "root-wins" }),
        "/test/repo/.bare/project.json": JSON.stringify({ primary_branch: "bare-loses" }),
      }))
    )

    expect(result.primary_branch).toBe("root-wins")
  })

  it("returns DEFAULT_CONFIG when project.json exists but is unreadable", async () => {
    const result = await Effect.runPromise(
      readConfig("/test/repo").pipe(provide({
        "/test/repo/project.json": null
      }))
    )

    expect(result).toEqual(DEFAULT_CONFIG)
  })

  it("returns ProjectConfigParseError for invalid JSON", async () => {
    const exit = await Effect.runPromiseExit(
      readConfig("/test/repo").pipe(provide({
        "/test/repo/project.json": "{ invalid json }"
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
      readConfig("/test/repo").pipe(provide({
        "/test/repo/project.json": JSON.stringify(config, null, 2)
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
      readConfig("/test/repo").pipe(provide({
        "/test/repo/project.json": JSON.stringify(config, null, 2)
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
      readConfig("/test/repo").pipe(provide({
        "/test/repo/project.json": "{}"
      }))
    )

    expect(result).toEqual(DEFAULT_CONFIG)
  })

  it("returns ProjectConfigParseError for invalid merge_strategy", async () => {
    const config = {
      worktree: { merge_strategy: "invalid_strategy" }
    }

    const exit = await Effect.runPromiseExit(
      readConfig("/test/repo").pipe(provide({
        "/test/repo/project.json": JSON.stringify(config, null, 2)
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
      readConfig("/test/repo").pipe(provide({
        "/test/repo/project.json": JSON.stringify(config, null, 2)
      }))
    )

    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("ProjectConfigParseError")
  })
})
