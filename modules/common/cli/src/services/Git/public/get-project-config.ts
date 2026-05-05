import { Effect, Schema } from "effect"
import { FileSystem, Path } from "@effect/platform"
import type {} from "../config-types"
import { ProjectConfigSchema } from "../config-types"
import { ProjectConfigParseError } from "../errors"
import type { WorktreePath, GitCommonPath } from "../types"
import { ProjectPath, ProjectId } from "../types"
import { commonDir } from "./common-dir"
import { readJsonFile } from "../internal/read-json-file"

const CONFIG_FILENAME = "project.json"
const ID_FILENAME = "project.id"
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

/**
 * Read or create `project.id` (a UUID) from the git common dir.
 * Regenerates the file if it exists but doesn't contain a valid UUID.
 */
const ensureProjectId = (gitCommonDir: GitCommonPath) =>
  Effect.gen(function* () {
    const fs = yield* FileSystem.FileSystem
    const path = yield* Path.Path
    const idPath = path.join(gitCommonDir, ID_FILENAME)

    const existing = yield* fs.readFileString(idPath).pipe(
      Effect.map((s) => s.trim()),
      Effect.catchAll(() => Effect.succeed("")),
    )
    if (UUID_RE.test(existing)) return ProjectId(existing)

    const id = crypto.randomUUID()
    yield* fs.writeFileString(idPath, id + "\n")
    return ProjectId(id)
  })

/**
 * Read project.json from the git common dir, merging worktree-local overrides
 * when the given path is a worktree checkout. Also reads (or creates) the
 * project.id UUID.
 *
 * Precedence (highest first): worktree config > common dir config > schema defaults.
 */
export const getProjectConfig = (dir: ProjectPath | WorktreePath) =>
  Effect.gen(function* () {
    const path = yield* Path.Path
    const gitCommonDir = yield* commonDir(dir)
    const commonJson = yield* readJsonFile(path.join(gitCommonDir, CONFIG_FILENAME))

    // If dir is a worktree (differs from the common dir parent), overlay local config
    const projectRoot = path.resolve(gitCommonDir, "..")
    const normalDir = path.resolve(dir)
    const worktreeJson = normalDir !== projectRoot
      ? yield* readJsonFile(path.join(dir, CONFIG_FILENAME))
      : {}
    const merged = { ...commonJson, ...worktreeJson }

    const configPath = path.join(gitCommonDir, CONFIG_FILENAME)
    const config = yield* Schema.decode(ProjectConfigSchema)(merged).pipe(
      Effect.catchTag("ParseError", (e) =>
        Effect.fail(new ProjectConfigParseError({ path: configPath, message: e.message }))
      ),
    )
    const projectId = yield* ensureProjectId(gitCommonDir)

    // Derived defaults: name ← directory name, tmux_session ← name
    const name = config.name ?? path.basename(projectRoot)
    const tmux_session = config.tmux_session ?? name

    return { ...config, name, tmux_session, projectPath: ProjectPath(projectRoot), gitCommonDir, projectId }
  })
