import { describe, it, expect } from "bun:test"
import { Effect, Option } from "effect"
import { FileSystem, Path } from "@effect/platform"
import { isWorktree } from "./is-worktree"
import { AbsolutePath, WorktreePath } from "../types"

const mockFileSystem = (statResult: { type: string } | null): FileSystem.FileSystem =>
  FileSystem.FileSystem.of({
    stat: () => statResult ? Effect.succeed(statResult) : Effect.fail(new Error("not found")),
  } as any)

const mockPath = (): Path.Path =>
  Path.Path.of({
    join: (...paths: string[]) => paths.join("/"),
  } as any)

describe("isWorktree", () => {
  it("should return Some(worktreePath) when .git is a file (worktree)", async () => {
    const fs = mockFileSystem({ type: "File" })
    const path = mockPath()
    const result = await Effect.runPromise(
      isWorktree(AbsolutePath("/some/path"))
        .pipe(
          Effect.provideService(FileSystem.FileSystem, fs),
          Effect.provideService(Path.Path, path)
        )
    )
    expect(Option.isSome(result)).toBe(true)
    if (Option.isSome(result)) {
      expect(result.value).toBe(WorktreePath("/some/path"))
    }
  })

  it("should return None when .git is a directory (main repo)", async () => {
    const fs = mockFileSystem({ type: "Directory" })
    const path = mockPath()
    const result = await Effect.runPromise(
      isWorktree(AbsolutePath("/some/path"))
        .pipe(
          Effect.provideService(FileSystem.FileSystem, fs),
          Effect.provideService(Path.Path, path)
        )
    )
    expect(Option.isNone(result)).toBe(true)
  })

  it("should return None when .git does not exist", async () => {
    const fs = mockFileSystem(null)
    const path = mockPath()
    const result = await Effect.runPromise(
      isWorktree(AbsolutePath("/some/path"))
        .pipe(
          Effect.provideService(FileSystem.FileSystem, fs),
          Effect.provideService(Path.Path, path)
        )
    )
    expect(Option.isNone(result)).toBe(true)
  })
})
