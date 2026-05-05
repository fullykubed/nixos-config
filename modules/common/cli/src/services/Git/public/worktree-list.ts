import { Effect } from "effect"
import { Path } from "@effect/platform"
import { ShellService } from "../../Shell"
import type { Worktree, GitCommonPath } from "../types"
import { WorktreePath, BranchName, ProjectPath } from "../types"
import { getProjectConfig } from "./get-project-config"
import { toGitError } from "../errors"

export const worktreeList = (gitCommonDir: GitCommonPath) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const path = yield* Path.Path
    const { stdout } = yield* shell.exec("git", ["worktree", "list", "--porcelain"], { cwd: gitCommonDir }).pipe(
      Effect.catchTag("ShellError", toGitError)
    )

    const dir = ProjectPath(path.resolve(gitCommonDir, ".."))
    const config = yield* getProjectConfig(dir).pipe(
      Effect.catchAll(() => Effect.succeed(null))
    )

    return parseWorktreeList(stdout, config?.primary_branch)
  })

// Pure function, easy to test
export const parseWorktreeList = (output: string, primaryBranch?: string): readonly Worktree[] => {
  if (!output.trim()) return []
  const blocks = output.trim().split("\n\n")
  return blocks.map((block) => {
    const lines = block.split("\n")
    const path = WorktreePath(lines.find(l => l.startsWith("worktree "))?.slice(9) ?? "")
    const head = lines.find(l => l.startsWith("HEAD "))?.slice(5) ?? ""
    const branchLine = lines.find(l => l.startsWith("branch "))
    const branch = branchLine ? BranchName(branchLine.slice(7).replace("refs/heads/", "")) : null
    const bare = lines.some(l => l === "bare")
    const locked = lines.some(l => l.startsWith("locked"))
    const prunable = lines.some(l => l === "prunable")
    const isPrimary = primaryBranch !== undefined && branch === primaryBranch
    return { path, head, branch, isPrimary, bare, locked, prunable }
  })
}
