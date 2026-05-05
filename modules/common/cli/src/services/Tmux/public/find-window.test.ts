import { describe, it, expect } from "bun:test"
import { Effect, Option } from "effect"
import { ShellService } from "../../Shell"
import { findWindow } from "./find-window"

describe("findWindow", () => {
  it("finds window by exact name match", async () => {
    const result = await Effect.runPromise(
      findWindow("vim").pipe(Effect.provideService(ShellService, {
        exec: () => Effect.succeed({
          stdout: "@0:0:main:1\n@1:1:vim:0\n@2:2:shell:0\n",
          stderr: "",
          exitCode: 0,
        }),
      } as any))
    )

    expect(result).toEqual(Option.some({ id: "@1", index: 1, name: "vim", active: false }))
  })

  it("finds window by pattern match (case insensitive)", async () => {
    const result = await Effect.runPromise(
      findWindow("VIM").pipe(Effect.provideService(ShellService, {
        exec: () => Effect.succeed({
          stdout: "@0:0:main:1\n@1:1:vim-editor:0\n@2:2:shell:0\n",
          stderr: "",
          exitCode: 0,
        }),
      } as any))
    )

    expect(result).toEqual(Option.some({ id: "@1", index: 1, name: "vim-editor", active: false }))
  })

  it("finds window by regex pattern", async () => {
    const result = await Effect.runPromise(
      findWindow("sh.*l").pipe(Effect.provideService(ShellService, {
        exec: () => Effect.succeed({
          stdout: "@0:0:main:1\n@1:1:vim:0\n@2:2:shell:0\n",
          stderr: "",
          exitCode: 0,
        }),
      } as any))
    )

    expect(result).toEqual(Option.some({ id: "@2", index: 2, name: "shell", active: false }))
  })

  it("returns first matching window when multiple matches exist", async () => {
    const result = await Effect.runPromise(
      findWindow("test").pipe(Effect.provideService(ShellService, {
        exec: () => Effect.succeed({
          stdout: "@0:0:test-1:0\n@1:1:test-2:0\n@2:2:other:1\n",
          stderr: "",
          exitCode: 0,
        }),
      } as any))
    )

    expect(result).toEqual(Option.some({ id: "@0", index: 0, name: "test-1", active: false }))
  })

  it("returns null when no window matches", async () => {
    const result = await Effect.runPromise(
      findWindow("nonexistent").pipe(Effect.provideService(ShellService, {
        exec: () => Effect.succeed({
          stdout: "@0:0:main:1\n@1:1:vim:0\n@2:2:shell:0\n",
          stderr: "",
          exitCode: 0,
        }),
      } as any))
    )

    expect(Option.isNone(result)).toBe(true)
  })

  it("returns null when no windows exist", async () => {
    const result = await Effect.runPromise(
      findWindow("any").pipe(Effect.provideService(ShellService, {
        exec: () => Effect.succeed({
          stdout: "",
          stderr: "",
          exitCode: 0,
        }),
      } as any))
    )

    expect(Option.isNone(result)).toBe(true)
  })

  it("handles window names with special characters", async () => {
    const result = await Effect.runPromise(
      findWindow("branch").pipe(Effect.provideService(ShellService, {
        exec: () => Effect.succeed({
          stdout: "@0:0:main:1\n@1:1:\uf418 feature-branch:0\n@2:2:shell:0\n",
          stderr: "",
          exitCode: 0,
        }),
      } as any))
    )

    expect(result).toEqual(Option.some({ id: "@1", index: 1, name: "\uf418 feature-branch", active: false }))
  })
})
