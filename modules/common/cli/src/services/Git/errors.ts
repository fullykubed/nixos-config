import { Data, Effect } from "effect"
import type { ShellError } from "../Shell/errors"
import { reclassify } from "../../lib/reclassify"

// ── Git domain errors ────────────────────────────────────────────────

/** The cwd is not inside a git repository. */
export class GitNotRepoError extends Data.TaggedError("GitNotRepoError")<{
  readonly message: string
  readonly cause?: ShellError
}> {}

/** A remote repository does not exist or is inaccessible (HTTP 404, "repository not found"). */
export class GitRepoDoesNotExistError extends Data.TaggedError("GitRepoDoesNotExistError")<{
  readonly message: string
  readonly cause?: ShellError
}> {}

/** A branch, tag, pathspec, or other ref does not exist. */
export class GitRefDoesNotExistError extends Data.TaggedError("GitRefDoesNotExistError")<{
  readonly message: string
  readonly cause?: ShellError
}> {}

/** A named remote (e.g. "origin") is not configured. */
export class GitRemoteDoesNotExistError extends Data.TaggedError("GitRemoteDoesNotExistError")<{
  readonly message: string
  readonly cause?: ShellError
}> {}

/** Authentication or authorization failure against a remote. */
export class GitAuthError extends Data.TaggedError("GitAuthError")<{
  readonly message: string
  readonly cause?: ShellError
}> {}

/** Network-level failure (DNS, TLS, timeout). */
export class GitConnectivityError extends Data.TaggedError("GitConnectivityError")<{
  readonly message: string
  readonly cause?: ShellError
}> {}

/** Catch-all for unclassified git failures (merge conflicts, dirty worktrees, etc.). */
export class GitUnknownError extends Data.TaggedError("GitUnknownError")<{
  readonly message: string
  readonly cause?: ShellError
}> {}

/** project.json parse/validation failure. */
export class ProjectConfigParseError extends Data.TaggedError("ProjectConfigParseError")<{
  readonly path: string
  readonly message: string
  readonly cause?: unknown
}> {}

// ── Union type ───────────────────────────────────────────────────────

export type GitError =
  | GitNotRepoError
  | GitRepoDoesNotExistError
  | GitRefDoesNotExistError
  | GitRemoteDoesNotExistError
  | GitAuthError
  | GitConnectivityError
  | GitUnknownError

// ── Classifier ───────────────────────────────────────────────────────

/** First non-empty line of stderr — strips multi-line git noise
 *  like "Stopping at filesystem boundary (GIT_DISCOVERY_ACROSS_FILESYSTEM not set)." */
const firstLine = (stderr: string): string =>
  stderr.split("\n").find((l) => l.trim().length > 0)?.trim() ?? stderr.trim()

export const classifyGitError = (e: ShellError): GitError => {
  const s = `${e.stderr}\n${e.stdout}`.toLowerCase()

  // Not a repo
  if (s.includes("not a git repository"))
    return new GitNotRepoError({ message: firstLine(e.stderr), cause: e })

  // Ref / pathspec / branch does not exist
  if (
    s.includes("pathspec") && s.includes("did not match") ||
    s.includes("not something we can merge") ||
    s.includes("unknown revision") ||
    s.includes("invalid reference") ||
    s.includes("cannot be resolved to commit") ||
    s.includes("refname") && s.includes("not found") ||
    s.includes("is not a commit") ||
    s.includes("did not match any file(s) known to git")
  )
    return new GitRefDoesNotExistError({ message: firstLine(e.stderr), cause: e })

  // Remote does not exist
  if (s.includes("no such remote") || s.includes("no url configured"))
    return new GitRemoteDoesNotExistError({ message: firstLine(e.stderr), cause: e })

  // Remote repository does not exist (404)
  if (s.includes("repository not found") || s.includes("does not appear to be a git repository"))
    return new GitRepoDoesNotExistError({ message: firstLine(e.stderr), cause: e })

  // Auth
  if (
    s.includes("authentication failed") ||
    s.includes("permission denied") ||
    s.includes("could not read from remote repository") && s.includes("permission") ||
    s.includes("invalid credentials") ||
    s.includes("authorization failed")
  )
    return new GitAuthError({ message: firstLine(e.stderr), cause: e })

  // Connectivity
  if (
    s.includes("could not resolve host") ||
    s.includes("unable to access") ||
    s.includes("connection refused") ||
    s.includes("connection timed out") ||
    s.includes("network is unreachable") ||
    s.includes("name or service not known") ||
    s.includes("ssl") && s.includes("error")
  )
    return new GitConnectivityError({ message: firstLine(e.stderr), cause: e })

  // Catch-all
  return new GitUnknownError({ message: firstLine(e.stderr), cause: e })
}

/** Convert a ShellError into a classified GitError. Use with Effect.catchTag("ShellError", toGitError). */
export const toGitError = (e: ShellError) =>
  Effect.fail(reclassify(e, classifyGitError))
