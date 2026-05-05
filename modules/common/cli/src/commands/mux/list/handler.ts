import { Effect } from "effect"
import type { Parsed } from "./command"
import { GitService, AbsolutePath } from "../../../services/Git"
import { TmuxService, WINDOW_PREFIX } from "../../../services/Tmux"
import { MuxService } from "../../../services/Mux"
import { table, json } from "../../../lib/output"

interface MuxListEntry {
  branch: string
  path: string
  window: string       // 'open' | 'closed'
  repo?: string        // only in --all mode
}

export const listHandler = (parsed: Parsed) =>
  Effect.gen(function* () {
    const git = yield* GitService
    const tmux = yield* TmuxService
    const mux = yield* MuxService

    const isAll = parsed.flags.all
    const isJson = parsed.flags.json

    if (isAll) {
      // Show worktrees across all projects from SQLite
      const muxRecords = yield* mux.listAll()
      const tmuxWindows = yield* tmux.listWindows()

      const entries = muxRecords.map((record): MuxListEntry => {
        const expectedWindowName = `${WINDOW_PREFIX}${record.branch}`
        const hasOpenWindow = tmuxWindows.some(w => w.name === expectedWindowName)

        return {
          branch: record.branch,
          path: record.project_path,
          window: hasOpenWindow ? 'open' : 'closed',
          repo: record.project_path
        }
      })

      if (isJson) {
        json(entries)
      } else {
        const headers = ['Branch', 'Path', 'Window', 'Repo']
        const rows = entries.map(entry => [
          entry.branch,
          entry.path,
          entry.window,
          entry.repo!
        ])
        table(headers, rows)
      }
    } else {
      // Show worktrees for current repo only
      const cwd = AbsolutePath(process.cwd())
      const repoRoot = yield* git.repoRoot(cwd)
      const projectPath = yield* git.projectDir(repoRoot)
      const config = yield* git.getProjectConfig(projectPath)
      const gitCommonDir = yield* git.commonDir(repoRoot)
      const worktrees = yield* git.worktreeList(gitCommonDir)
      const muxRecords = yield* mux.listByProject(projectPath)
      const tmuxWindows = yield* tmux.listWindows()

      // Filter out primary branch worktree and bare entries
      const nonMainWorktrees = worktrees.filter(w => w.branch !== config.primary_branch && !w.bare)

      const entries: MuxListEntry[] = []

      // Process git worktrees and match with SQLite records
      for (const worktree of nonMainWorktrees) {
        if (!worktree.branch) continue // skip if detached HEAD

        const expectedWindowName = `${WINDOW_PREFIX}${worktree.branch}`
        const hasOpenWindow = tmuxWindows.some(w => w.name === expectedWindowName)

        entries.push({
          branch: worktree.branch,
          path: worktree.path,
          window: hasOpenWindow ? 'open' : 'closed',
        })
      }

      // Also include any SQLite records that might not have corresponding git worktrees
      for (const muxRecord of muxRecords) {
        if (!nonMainWorktrees.some(w => w.branch === muxRecord.branch)) {
          const expectedWindowName = `${WINDOW_PREFIX}${muxRecord.branch}`
          const hasOpenWindow = tmuxWindows.some(w => w.name === expectedWindowName)

          entries.push({
            branch: muxRecord.branch,
            path: muxRecord.project_path,
            window: hasOpenWindow ? 'open' : 'closed',
          })
        }
      }

      // Sort by branch name
      entries.sort((a, b) => a.branch.localeCompare(b.branch))

      if (isJson) {
        json(entries)
      } else {
        const headers = ['Branch', 'Path', 'Window']
        const rows = entries.map(entry => [
          entry.branch,
          entry.path,
          entry.window,
        ])
        table(headers, rows)
      }
    }
  })
