import { describe, it, expect } from "bun:test"
import { Context, Effect } from "effect"
import { ShellService } from "../../Shell"
import { ProjectId } from "../../Git"
import { findSessionByProjectId, parseSessionList } from "./find-session-by-project-id"

const PROJECT_ID = ProjectId("550e8400-e29b-41d4-a716-446655440000")

describe("parseSessionList", () => {
  it("returns session name matching the project id", () => {
    const stdout = [
      "work:7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "my-project:550e8400-e29b-41d4-a716-446655440000",
      "scratch:",
    ].join("\n")

    expect(parseSessionList(stdout, PROJECT_ID)).toBe("my-project")
  })

  it("returns undefined when no session matches", () => {
    const stdout = [
      "work:7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "scratch:",
    ].join("\n")

    expect(parseSessionList(stdout, PROJECT_ID)).toBeUndefined()
  })

  it("returns undefined for empty output", () => {
    expect(parseSessionList("", PROJECT_ID)).toBeUndefined()
  })

  it("handles session names containing colons", () => {
    const stdout = "my:project:550e8400-e29b-41d4-a716-446655440000\n"
    expect(parseSessionList(stdout, PROJECT_ID)).toBe("my:project")
  })

  it("skips lines without a colon separator", () => {
    const stdout = "malformed-line\ngood:550e8400-e29b-41d4-a716-446655440000\n"
    expect(parseSessionList(stdout, PROJECT_ID)).toBe("good")
  })
})

describe("findSessionByProjectId", () => {
  const makeShellMock = (stdout: string) => Context.empty().pipe(
    Context.add(ShellService, {
      exec: () => Effect.succeed({ stdout, stderr: "", exitCode: 0 }),
      execLines: () => Effect.succeed([]),
      execJson: () => Effect.succeed({}),
    } as any)
  )

  it("returns matching session name from tmux output", async () => {
    const stdout = `default:\ntagged:${PROJECT_ID}\n`
    const result = await Effect.runPromise(
      findSessionByProjectId(PROJECT_ID).pipe(Effect.provide(makeShellMock(stdout)))
    )
    expect(result).toBe("tagged")
  })

  it("returns undefined when no session matches", async () => {
    const result = await Effect.runPromise(
      findSessionByProjectId(PROJECT_ID).pipe(Effect.provide(makeShellMock("other:nope\n")))
    )
    expect(result).toBeUndefined()
  })

  it("returns undefined when shell command fails", async () => {
    const FailingShell = Context.empty().pipe(
      Context.add(ShellService, {
        exec: () => Effect.fail({ _tag: "ShellError", command: "tmux", exitCode: 1, stdout: "", stderr: "no server" }),
        execLines: () => Effect.succeed([]),
        execJson: () => Effect.succeed({}),
      } as any)
    )

    const result = await Effect.runPromise(
      findSessionByProjectId(PROJECT_ID).pipe(Effect.provide(FailingShell))
    )
    expect(result).toBeUndefined()
  })
})
