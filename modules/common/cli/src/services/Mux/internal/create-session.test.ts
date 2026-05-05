import { describe, it, expect } from "bun:test"
import { Context, Effect, Either } from "effect"
import { ShellService } from "../../Shell"
import { TmuxService } from "../../Tmux"
import { ProjectId } from "../../Git"
import { createSession } from "./create-session"

const PROJECT_ID = ProjectId("00000000-0000-0000-0000-000000000000")
const SESSION_NAME = "my-session"

describe("createSession", () => {
  const MockShell = Context.empty().pipe(
    Context.add(ShellService, {
      exec: () => Effect.succeed({ stdout: "", stderr: "", exitCode: 0 }),
      execLines: () => Effect.succeed([]),
      execJson: () => Effect.succeed({}),
    } as any)
  )

  const makeTmuxMock = (overrides?: Record<string, unknown>) => Context.empty().pipe(
    Context.add(TmuxService, {
      isInsideTmux: () => Effect.succeed(true),
      currentSession: () => Effect.succeed("default"),
      sessionExists: () => Effect.succeed(true),
      renameSession: () => Effect.void,
      ensureSession: () => Effect.void,
      setSessionOption: () => Effect.void,
      ...overrides,
    } as any)
  )

  const run = <A, E>(
    effect: Effect.Effect<A, E, any>,
    ctx?: { shell?: typeof MockShell; tmux?: ReturnType<typeof makeTmuxMock> },
  ) =>
    Effect.runPromise(effect.pipe(
      Effect.provide(ctx?.shell ?? MockShell),
      Effect.provide(ctx?.tmux ?? makeTmuxMock()),
    ) as Effect.Effect<A, E>)

  it("returns the session name", async () => {
    const result = await run(createSession(SESSION_NAME, PROJECT_ID))
    expect(result).toBe(SESSION_NAME)
  })

  it("no-ops when session with correct name already exists", async () => {
    let ensureCalled = false
    let renameCalled = false

    await run(
      createSession(SESSION_NAME, PROJECT_ID),
      {
        tmux: makeTmuxMock({
          sessionExists: () => Effect.succeed(true),
          ensureSession: () => { ensureCalled = true; return Effect.void },
          renameSession: () => { renameCalled = true; return Effect.void },
        }),
      },
    )

    expect(ensureCalled).toBe(false)
    expect(renameCalled).toBe(false)
  })

  it("creates new session when no matching session exists", async () => {
    let ensuredName: string | undefined

    await run(
      createSession(SESSION_NAME, PROJECT_ID),
      {
        tmux: makeTmuxMock({
          sessionExists: () => Effect.succeed(false),
          ensureSession: (name: string) => { ensuredName = name; return Effect.void },
        }),
      },
    )

    expect(ensuredName).toBe(SESSION_NAME)
  })

  it("renames existing session when one has matching @mux_project_id", async () => {
    let renamedFrom: string | undefined
    let renamedTo: string | undefined
    let ensureCalled = false

    const TaggedShell = Context.empty().pipe(
      Context.add(ShellService, {
        exec: () => Effect.succeed({
          stdout: `other-session:nope\nold-session:${PROJECT_ID}\n`,
          stderr: "",
          exitCode: 0,
        }),
        execLines: () => Effect.succeed([]),
        execJson: () => Effect.succeed({}),
      } as any)
    )

    await run(
      createSession(SESSION_NAME, PROJECT_ID),
      {
        shell: TaggedShell,
        tmux: makeTmuxMock({
          sessionExists: () => Effect.succeed(false),
          renameSession: (oldName: string, newName: string) => {
            renamedFrom = oldName
            renamedTo = newName
            return Effect.void
          },
          ensureSession: () => { ensureCalled = true; return Effect.void },
        }),
      },
    )

    expect(renamedFrom).toBe("old-session")
    expect(renamedTo).toBe(SESSION_NAME)
    expect(ensureCalled).toBe(false)
  })

  it("tags session with @mux_project_id", async () => {
    let taggedKey: string | undefined
    let taggedValue: string | undefined
    let taggedSession: string | undefined

    await run(
      createSession(SESSION_NAME, PROJECT_ID),
      {
        tmux: makeTmuxMock({
          setSessionOption: (key: string, value: string, session: string) => {
            taggedKey = key
            taggedValue = value
            taggedSession = session
            return Effect.void
          },
        }),
      },
    )

    expect(taggedKey).toBe("@mux_project_id")
    expect(taggedValue).toBe(PROJECT_ID)
    expect(taggedSession).toBe(SESSION_NAME)
  })

  it("wraps ensureSession failure in MuxTmuxSyncError", async () => {
    const tmuxError = { _tag: "TmuxCommandError", operation: "ensureSession", message: "fail" }

    const result = await run(
      createSession(SESSION_NAME, PROJECT_ID).pipe(Effect.either),
      {
        tmux: makeTmuxMock({
          sessionExists: () => Effect.succeed(false),
          ensureSession: () => Effect.fail(tmuxError),
        }),
      },
    )

    expect(Either.isLeft(result)).toBe(true)
    if (Either.isLeft(result)) {
      const err = result.left as { _tag: string; cause: unknown }
      expect(err._tag).toBe("MuxTmuxSyncError")
      expect(err.cause).toBe(tmuxError)
    }
  })

  it("wraps setSessionOption failure in MuxTmuxSyncError", async () => {
    const tmuxError = { _tag: "TmuxCommandError", operation: "setSessionOption", message: "fail" }

    const result = await run(
      createSession(SESSION_NAME, PROJECT_ID).pipe(Effect.either),
      {
        tmux: makeTmuxMock({
          setSessionOption: () => Effect.fail(tmuxError),
        }),
      },
    )

    expect(Either.isLeft(result)).toBe(true)
    if (Either.isLeft(result)) {
      const err = result.left as { _tag: string; cause: unknown }
      expect(err._tag).toBe("MuxTmuxSyncError")
      expect(err.cause).toBe(tmuxError)
    }
  })

  it("wraps renameSession failure in MuxTmuxSyncError", async () => {
    const tmuxError = { _tag: "TmuxCommandError", operation: "renameSession", message: "fail" }

    const TaggedShell = Context.empty().pipe(
      Context.add(ShellService, {
        exec: () => Effect.succeed({
          stdout: `tagged-session:${PROJECT_ID}\n`,
          stderr: "",
          exitCode: 0,
        }),
        execLines: () => Effect.succeed([]),
        execJson: () => Effect.succeed({}),
      } as any)
    )

    const result = await run(
      createSession(SESSION_NAME, PROJECT_ID).pipe(Effect.either),
      {
        shell: TaggedShell,
        tmux: makeTmuxMock({
          sessionExists: () => Effect.succeed(false),
          renameSession: () => Effect.fail(tmuxError),
        }),
      },
    )

    expect(Either.isLeft(result)).toBe(true)
    if (Either.isLeft(result)) {
      const err = result.left as { _tag: string; cause: unknown }
      expect(err._tag).toBe("MuxTmuxSyncError")
      expect(err.cause).toBe(tmuxError)
    }
  })
})
