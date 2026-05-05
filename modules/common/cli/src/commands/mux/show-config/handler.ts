import { Effect } from "effect"
import type { Parsed } from "./command"
import { GitService, AbsolutePath } from "../../../services/Git"
import { table, json } from "../../../lib/output"

export const showConfigHandler = (parsed: Parsed) =>
  Effect.gen(function* () {
    const git = yield* GitService

    const cwd = AbsolutePath(process.cwd())
    const repoRoot = yield* git.repoRoot(cwd)
    const projectPath = yield* git.projectDir(repoRoot)
    const config = yield* git.getProjectConfig(projectPath)

    if (parsed.flags.json) {
      json(config)
    } else {
      const rows: string[][] = [
        ["name", config.name],
        ["tmux_session", config.tmux_session],
        ["primary_branch", config.primary_branch],
        ["merge_strategy", config.worktree.merge_strategy],
        ["files.copy", config.worktree.files.copy.join(", ") || "(none)"],
        ["files.link", config.worktree.files.link.join(", ") || "(none)"],
        ["post_create", config.worktree.post_create.join(", ") || "(none)"],
        ["pre_merge", config.worktree.pre_merge.join(", ") || "(none)"],
        ["panes", `${config.worktree.panes.length} pane(s)`],
        ["project_path", config.projectPath],
        ["project_id", config.projectId],
      ]
      table(["Key", "Value"], rows)
    }
  })
