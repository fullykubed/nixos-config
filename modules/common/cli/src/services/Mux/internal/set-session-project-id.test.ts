import { describe, it, expect } from "bun:test"
import { Context, Effect, Either } from "effect"
import { TmuxService } from "../../Tmux"
import { ProjectId } from "../../Git"
import { setSessionProjectId } from "./set-session-project-id"

const PROJECT_ID = ProjectId("550e8400-e29b-41d4-a716-446655440000")

describe("setSessionProjectId", () => {
  it("calls setSessionOption with @mux_project_id key", async () => {
    let calledKey: string | undefined
    let calledValue: string | undefined
    let calledSession: string | undefined

    const MockTmux = Context.empty().pipe(
      Context.add(TmuxService, {
        setSessionOption: (key: string, value: string, session: string) => {
          calledKey = key
          calledValue = value
          calledSession = session
          return Effect.void
        },
      } as any)
    )

    await Effect.runPromise(
      setSessionProjectId("my-session", PROJECT_ID).pipe(Effect.provide(MockTmux))
    )

    expect(calledKey).toBe("@mux_project_id")
    expect(calledValue).toBe(PROJECT_ID)
    expect(calledSession).toBe("my-session")
  })

  it("wraps setSessionOption failure in MuxTmuxSyncError", async () => {
    const tmuxError = { _tag: "TmuxCommandError", operation: "setSessionOption", message: "fail" }
    const MockTmux = Context.empty().pipe(
      Context.add(TmuxService, {
        setSessionOption: () => Effect.fail(tmuxError),
      } as any)
    )

    const result = await Effect.runPromise(
      setSessionProjectId("my-session", PROJECT_ID).pipe(
        Effect.either,
        Effect.provide(MockTmux),
      )
    )

    expect(Either.isLeft(result)).toBe(true)
    if (Either.isLeft(result)) {
      const err = result.left as { _tag: string; cause: unknown }
      expect(err._tag).toBe("MuxTmuxSyncError")
      expect(err.cause).toBe(tmuxError)
    }
  })
})
