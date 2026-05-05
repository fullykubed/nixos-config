import { Brand } from "effect"
import { AbsolutePath } from "../../lib/types/absolute-path"
export { AbsolutePath } from "../../lib/types/absolute-path"

// ── Branded path types ──────────────────────────────────────────────

/** Parent directory of the git common dir (e.g. `/repo`). Canonical project identity. */
export type ProjectPath = AbsolutePath & Brand.Brand<"ProjectPath">
const ProjectPathTag = Brand.nominal<string & Brand.Brand<"ProjectPath">>()
export const ProjectPath = Brand.all(AbsolutePath, ProjectPathTag)

/** The git common dir, stable across worktrees (e.g. `/repo/.git` or `/repo/.bare`). */
export type GitCommonPath = AbsolutePath & Brand.Brand<"GitCommonPath">
const GitCommonPathTag = Brand.nominal<string & Brand.Brand<"GitCommonPath">>()
export const GitCommonPath = Brand.all(AbsolutePath, GitCommonPathTag)

/** Absolute path to a git worktree checkout (e.g. `/repo/../feature-branch`). */
export type WorktreePath = AbsolutePath & Brand.Brand<"WorktreePath">
const WorktreePathTag = Brand.nominal<string & Brand.Brand<"WorktreePath">>()
export const WorktreePath = Brand.all(AbsolutePath, WorktreePathTag)

/** A git branch name (e.g. `main`, `feature-branch`). */
export type BranchName = string & Brand.Brand<"BranchName">

/** Validate a string against git check-ref-format rules. */
export const isValidBranchName = (s: string): s is BranchName =>
  s.length > 0 &&
  s !== "@" &&
  !s.startsWith("-") &&
  !s.startsWith(".") &&
  !s.endsWith(".") &&
  !s.startsWith("/") &&
  !s.endsWith("/") &&
  !s.endsWith(".lock") &&
  !s.includes("..") &&
  !s.includes("//") &&
  !s.includes("@{") &&
  !s.includes("/.") &&
  // eslint-disable-next-line no-control-regex -- git branch names must reject control characters
  !/[\x00-\x1f\x7f ~^:?*[\]\\]/.test(s)

export const BranchName = Brand.refined<BranchName>(
  isValidBranchName,
  () => Brand.error("a valid git branch name")
)

/** UUID project identifier, stored in `project.id` in the git common dir. */
export type ProjectId = string & Brand.Brand<"ProjectId">

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/** Validate a string is a well-formed UUID. */
export const isValidProjectId = (s: string): s is ProjectId => UUID_RE.test(s)

export const ProjectId = Brand.refined<ProjectId>(
  isValidProjectId,
  () => Brand.error("a valid UUID")
)

// ── Domain types ────────────────────────────────────────────────────

export interface Worktree {
  readonly path: WorktreePath
  readonly head: string
  readonly branch: BranchName | null  // null if detached
  readonly isPrimary: boolean          // true for the worktree on the primary_branch from project config
  readonly bare: boolean
  readonly locked: boolean
  readonly prunable: boolean
}