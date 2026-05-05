import { afterAll, beforeAll, describe, expect, it } from "bun:test"
import { Effect, Exit, Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { ShellService } from "../../Shell"
import { TmuxWindowNotFoundError } from "../errors"
import { WINDOW_PREFIX } from "../config"
import { createWindow } from "../public/create-window"
import { listWindows } from "../public/list-windows"
import { findWindow } from "../public/find-window"
import { killWindow } from "../public/kill-window"
import { switchWindow } from "../public/switch-window"
import { splitPane } from "../public/split-pane"
import { sendKeys } from "../public/send-keys"
import { selectPane } from "../public/select-pane"
import { makeIsolatedTmuxShell } from "./setup.test"

// Unique socket name for test isolation — no collision with user's tmux
const socket = `j-test-${process.pid}`

const TestLayer = makeIsolatedTmuxShell(socket).pipe(
  Layer.provideMerge(BunContext.layer),
)

const run = <A, E>(effect: Effect.Effect<A, E, ShellService>) =>
  effect.pipe(Effect.provide(TestLayer), Effect.runPromise)

const runExit = <A, E>(effect: Effect.Effect<A, E, ShellService>) =>
  effect.pipe(Effect.provide(TestLayer), Effect.runPromiseExit)

/** Run a raw tmux command on the isolated socket for test setup/verification. */
const tmux = (...args: string[]) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const { stdout } = yield* shell.exec("tmux", args)
    return stdout.trim()
  })

beforeAll(() => run(tmux("new-session", "-d", "-s", "test")))

afterAll(() =>
  run(tmux("kill-server")).catch(() => {
    // Server may already be dead
  }),
)

describe.serial("Tmux integration", () => {
  describe.serial("listWindows", () => {
    it("returns the default session window", () =>
      run(
        Effect.gen(function* () {
          const windows = yield* listWindows()
          expect(windows.length).toBeGreaterThanOrEqual(1)
          expect(windows[0]?.index).toBe(0)
          expect(typeof windows[0]?.name).toBe("string")
          expect(typeof windows[0]?.active).toBe("boolean")
        }),
      ))
  })

  describe("window lifecycle", () => {
    const windowName = "integ-lifecycle"
    const fullName = `${WINDOW_PREFIX}${windowName}`

    beforeAll(() => run(createWindow({ name: windowName, cwd: "/tmp" })))
    afterAll(() => run(killWindow(fullName).pipe(Effect.ignore)))

    it("createWindow adds a window visible in listWindows", () =>
      run(
        Effect.gen(function* () {
          const windows = yield* listWindows()
          const found = windows.find((w) => w.name === fullName)
          expect(found).toBeDefined()
          expect(found!.index).toBeGreaterThan(0)
        }),
      ))

    it("findWindow matches by regex pattern", () =>
      run(
        Effect.gen(function* () {
          const found = yield* findWindow("integ-lifecycle")
          expect(found).not.toBeNull()
          expect(found!.name).toBe(fullName)
        }),
      ))

    it("findWindow returns null for non-matching pattern", () =>
      run(
        Effect.gen(function* () {
          const found = yield* findWindow("zzz-no-match-zzz")
          expect(found).toBeNull()
        }),
      ))
  })

  describe("killWindow", () => {
    const windowName = "integ-kill"
    const fullName = `${WINDOW_PREFIX}${windowName}`

    beforeAll(() => run(createWindow({ name: windowName, cwd: "/tmp" })))
    afterAll(() => run(killWindow(fullName).pipe(Effect.ignore)))

    it("removes the window", () =>
      run(
        Effect.gen(function* () {
          yield* killWindow(fullName)
          const windows = yield* listWindows()
          const found = windows.find((w) => w.name === fullName)
          expect(found).toBeUndefined()
        }),
      ))
  })

  describe.serial("switchWindow", () => {
    const winA = "switch-a"
    const winB = "switch-b"
    const fullA = `${WINDOW_PREFIX}${winA}`
    const fullB = `${WINDOW_PREFIX}${winB}`

    afterAll(() =>
      run(
        Effect.gen(function* () {
          yield* killWindow(fullA).pipe(Effect.ignore)
          yield* killWindow(fullB).pipe(Effect.ignore)
        }),
      ),
    )

    it("switching sets the target window as active", () =>
      run(
        Effect.gen(function* () {
          yield* createWindow({ name: winA, cwd: "/tmp" })
          yield* createWindow({ name: winB, cwd: "/tmp" })

          // winB is active after creation; switch to winA
          yield* switchWindow(fullA)
          const windows = yield* listWindows()

          const a = windows.find((w) => w.name === fullA)
          expect(a).toBeDefined()
          expect(a!.active).toBe(true)

          const b = windows.find((w) => w.name === fullB)
          expect(b).toBeDefined()
          expect(b!.active).toBe(false)
        }),
      ))
  })

  describe.serial("pane operations", () => {
    const paneName = "pane-test"
    const fullName = `${WINDOW_PREFIX}${paneName}`

    beforeAll(() => run(createWindow({ name: paneName, cwd: "/tmp" })))
    afterAll(() => run(killWindow(fullName).pipe(Effect.ignore)))

    it("splitPane creates additional panes", () =>
      run(
        Effect.gen(function* () {
          yield* splitPane({ direction: "horizontal", target: fullName })
          const output = yield* tmux("list-panes", "-t", fullName)
          const paneCount = output.split("\n").filter((l) => l.length > 0).length
          expect(paneCount).toBe(2)
        }),
      ))

    it("sendKeys does not error on valid target", () =>
      run(sendKeys(`${fullName}.0`, "echo hello")))

    it("selectPane does not error on valid pane index", () =>
      run(
        Effect.gen(function* () {
          yield* switchWindow(fullName)
          yield* selectPane(0)
        }),
      ))
  })

  describe.serial("error handling", () => {
    it("killWindow on non-existent window fails with TmuxWindowNotFoundError", async () => {
      const exit = await runExit(killWindow("nonexistent-window-xyz"))
      expect(Exit.isFailure(exit)).toBe(true)
      if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
        expect(exit.cause.error).toBeInstanceOf(TmuxWindowNotFoundError)
        expect((exit.cause.error as TmuxWindowNotFoundError).name).toBe("nonexistent-window-xyz")
      }
    })

    it("switchWindow on non-existent window fails with TmuxWindowNotFoundError", async () => {
      const exit = await runExit(switchWindow("nonexistent-window-xyz"))
      expect(Exit.isFailure(exit)).toBe(true)
      if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
        expect(exit.cause.error).toBeInstanceOf(TmuxWindowNotFoundError)
        expect((exit.cause.error as TmuxWindowNotFoundError).name).toBe("nonexistent-window-xyz")
      }
    })
  })
})
