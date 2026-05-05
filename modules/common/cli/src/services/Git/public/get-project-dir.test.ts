import { describe, it, expect } from "bun:test"
import { Effect, Layer } from "effect"
import { FileSystem } from "@effect/platform"
import { BunContext } from "@effect/platform-bun"
import { projectDir } from "./get-project-dir"
import { ProjectPath } from "../types"
import { ShellService } from "../../Shell"

const makeShellLayer = (commonDirOutput: string) =>
  Layer.succeed(
    ShellService,
    ShellService.of({
      exec: () => Effect.succeed({ stdout: `${commonDirOutput}\n`, stderr: "", exitCode: 0 }),
      execJson: () => Effect.succeed({}) as any,
      execLines: () => Effect.succeed([]) as any,
    }),
  )

const makeFsLayer = () =>
  Layer.succeed(
    FileSystem.FileSystem,
    { stat: () => Effect.succeed(null) } as unknown as FileSystem.FileSystem,
  )

describe("projectDir", () => {
  it("returns parent of commonDir for a normal repo", async () => {
    const result = await projectDir(ProjectPath("/some/cwd")).pipe(
      Effect.provide(makeShellLayer("/home/user/repo/.git")),
      Effect.provide(makeFsLayer()),
      Effect.provide(BunContext.layer),
      Effect.runPromise,
    )
    expect(result).toBe(ProjectPath("/home/user/repo"))
  })

  it("returns parent of commonDir for a bare repo", async () => {
    const result = await projectDir(ProjectPath("/some/cwd")).pipe(
      Effect.provide(makeShellLayer("/home/user/repo/.bare")),
      Effect.provide(makeFsLayer()),
      Effect.provide(BunContext.layer),
      Effect.runPromise,
    )
    expect(result).toBe(ProjectPath("/home/user/repo"))
  })

  it("returns parent of commonDir for a nested path", async () => {
    const result = await projectDir(ProjectPath("/some/cwd")).pipe(
      Effect.provide(makeShellLayer("/home/user/projects/my-app/.git")),
      Effect.provide(makeFsLayer()),
      Effect.provide(BunContext.layer),
      Effect.runPromise,
    )
    expect(result).toBe(ProjectPath("/home/user/projects/my-app"))
  })

  it("passes cwd through to commonDir", async () => {
    let capturedOpts: any
    const shell = Layer.succeed(
      ShellService,
      ShellService.of({
        exec: (_cmd, _args, opts) => {
          capturedOpts = opts
          return Effect.succeed({ stdout: "/tmp/repo/.git\n", stderr: "", exitCode: 0 })
        },
        execJson: () => Effect.succeed({}) as any,
        execLines: () => Effect.succeed([]) as any,
      }),
    )

    await projectDir(ProjectPath("/some/path")).pipe(
      Effect.provide(shell),
      Effect.provide(makeFsLayer()),
      Effect.provide(BunContext.layer),
      Effect.runPromise,
    )
    expect(capturedOpts).toEqual({ cwd: "/some/path" })
  })
})
