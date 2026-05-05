import { Effect } from "effect"
import { Path } from "@effect/platform"
import type { WorktreePath } from "../types"
import { ProjectPath } from "../types"
import type {} from "../errors"
import { commonDir } from "./common-dir"

export const projectDir = (cwd: ProjectPath | WorktreePath) =>
  Effect.gen(function* () {
    const p = yield* Path.Path
    const dir = yield* commonDir(cwd)
    return ProjectPath(p.resolve(dir, ".."))
  })
