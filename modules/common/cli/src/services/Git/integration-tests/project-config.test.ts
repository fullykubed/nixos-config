import { afterAll, beforeAll, describe, expect, it } from "bun:test"
import { rmSync, writeFileSync } from "node:fs"
import { join } from "node:path"
import { Effect, Either, Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { ShellLive } from "../../Shell"
import { createTmpRepo, git, run } from "./setup.test"
import { getProjectConfig } from "../public/get-project-config"
import { commonDir } from "../public/common-dir"
import { worktreeAdd } from "../public/worktree-add"
import { DEFAULT_CONFIG } from "../config-defaults"
import { ProjectPath, WorktreePath, BranchName, GitCommonPath } from "../types"

const FullLayer = ShellLive.pipe(Layer.provideMerge(BunContext.layer))

const runFull = <A, E>(effect: Effect.Effect<A, E, any>): Promise<A> =>
  Effect.runPromise(effect.pipe(Effect.provide(FullLayer)) as Effect.Effect<A>)

let tmpDir: string
let gitCommonDir: GitCommonPath

beforeAll(async () => {
  tmpDir = await createTmpRepo()
  gitCommonDir = await runFull(commonDir(ProjectPath(tmpDir)))
})

afterAll(() => {
  rmSync(tmpDir, { recursive: true, force: true })
})

describe.serial("getProjectConfig integration", () => {
  it("returns defaults when no project.json exists", () =>
    runFull(
      Effect.gen(function* () {
        const config = yield* getProjectConfig(ProjectPath(tmpDir))
        expect(config).toEqual(expect.objectContaining({ ...DEFAULT_CONFIG, projectPath: ProjectPath(tmpDir) }))
        expect(config.projectId).toBeDefined()
      }),
    ))

  it("reads project.json from the git common dir", () =>
    runFull(
      Effect.gen(function* () {
        const configPath = join(gitCommonDir, "project.json")
        writeFileSync(configPath, JSON.stringify({ primary_branch: "develop" }))
        yield* Effect.ensuring(
          Effect.gen(function* () {
            const config = yield* getProjectConfig(ProjectPath(tmpDir))
            expect(config.primary_branch).toBe("develop")
            expect(config.worktree).toEqual(DEFAULT_CONFIG.worktree)
          }),
          Effect.sync(() => { rmSync(configPath) }),
        )
      }),
    ))

  it("returns ProjectConfigParseError for invalid JSON", () =>
    runFull(
      Effect.gen(function* () {
        const configPath = join(gitCommonDir, "project.json")
        writeFileSync(configPath, "{ not valid json }")
        yield* Effect.ensuring(
          Effect.gen(function* () {
            const exit = yield* getProjectConfig(ProjectPath(tmpDir)).pipe(Effect.either)
            expect(Either.isLeft(exit)).toBe(true)
            if (Either.isLeft(exit)) {
              expect(exit.left._tag).toBe("ProjectConfigParseError")
            }
          }),
          Effect.sync(() => { rmSync(configPath) }),
        )
      }),
    ))
})

describe.serial("getProjectConfig worktree overlay integration", () => {
  const wtBranch = BranchName("config-test-wt")
  let wtPath: WorktreePath

  beforeAll(async () => {
    wtPath = await runFull(
      Effect.gen(function* () {
        yield* git(tmpDir, "branch", wtBranch)
        return yield* worktreeAdd(wtBranch, gitCommonDir, { create: false })
      }),
    )
  })

  afterAll(() =>
    run(
      Effect.gen(function* () {
        yield* git(tmpDir, "worktree", "remove", "--force", wtPath).pipe(Effect.ignore)
        yield* git(tmpDir, "branch", "-D", wtBranch).pipe(Effect.ignore)
      }),
    ),
  )

  it("returns defaults when no project.json exists anywhere", () =>
    runFull(
      Effect.gen(function* () {
        const config = yield* getProjectConfig(wtPath)
        expect(config).toEqual(expect.objectContaining({ ...DEFAULT_CONFIG, projectPath: ProjectPath(tmpDir) }))
        expect(config.projectId).toBeDefined()
      }),
    ))

  it("reads config from git common dir only", () =>
    runFull(
      Effect.gen(function* () {
        const configPath = join(gitCommonDir, "project.json")
        writeFileSync(configPath, JSON.stringify({ primary_branch: "trunk" }))
        yield* Effect.ensuring(
          Effect.gen(function* () {
            const config = yield* getProjectConfig(wtPath)
            expect(config.primary_branch).toBe("trunk")
            expect(config.worktree).toEqual(DEFAULT_CONFIG.worktree)
          }),
          Effect.sync(() => { rmSync(configPath) }),
        )
      }),
    ))

  it("reads config from worktree only", () =>
    runFull(
      Effect.gen(function* () {
        const configPath = join(wtPath, "project.json")
        writeFileSync(configPath, JSON.stringify({ primary_branch: "wt-branch" }))
        yield* Effect.ensuring(
          Effect.gen(function* () {
            const config = yield* getProjectConfig(wtPath)
            expect(config.primary_branch).toBe("wt-branch")
          }),
          Effect.sync(() => { rmSync(configPath) }),
        )
      }),
    ))

  it("worktree config overrides common dir config", () =>
    runFull(
      Effect.gen(function* () {
        const commonConfigPath = join(gitCommonDir, "project.json")
        const wtConfigPath = join(wtPath, "project.json")
        writeFileSync(commonConfigPath, JSON.stringify({ primary_branch: "from-common", name: "my-project" }))
        writeFileSync(wtConfigPath, JSON.stringify({ primary_branch: "from-worktree" }))
        yield* Effect.ensuring(
          Effect.gen(function* () {
            const config = yield* getProjectConfig(wtPath)
            expect(config.primary_branch).toBe("from-worktree")
            expect(config.name).toBe("my-project")
          }),
          Effect.sync(() => {
            rmSync(commonConfigPath)
            rmSync(wtConfigPath)
          }),
        )
      }),
    ))

  it("worktree overrides merge at top level, not deep", () =>
    runFull(
      Effect.gen(function* () {
        const commonConfigPath = join(gitCommonDir, "project.json")
        const wtConfigPath = join(wtPath, "project.json")
        writeFileSync(commonConfigPath, JSON.stringify({
          primary_branch: "develop",
          worktree: { merge_strategy: "squash", post_create: ["echo common"] },
        }))
        writeFileSync(wtConfigPath, JSON.stringify({
          worktree: { merge_strategy: "rebase" },
        }))
        yield* Effect.ensuring(
          Effect.gen(function* () {
            const config = yield* getProjectConfig(wtPath)
            expect(config.primary_branch).toBe("develop")
            // worktree.merge_strategy comes from worktree override
            expect(config.worktree.merge_strategy).toBe("rebase")
            // worktree key was fully replaced — post_create from common is NOT merged
            expect(config.worktree.post_create).toEqual(DEFAULT_CONFIG.worktree.post_create)
          }),
          Effect.sync(() => {
            rmSync(commonConfigPath)
            rmSync(wtConfigPath)
          }),
        )
      }),
    ))
})
