import { Context, Effect, Layer } from "effect"
import { ShellService } from "../Shell"
import { mkContextInjector } from "../../lib/mkContextInjector"
import { isInsideTmux } from "./public/is-inside-tmux"
import { currentSession } from "./public/current-session"
import { createWindow } from "./public/create-window"
import { splitPane } from "./public/split-pane"
import { sendKeys } from "./public/send-keys"
import { selectPane } from "./public/select-pane"
import { switchWindow } from "./public/switch-window"
import { killWindow } from "./public/kill-window"
import { listWindows } from "./public/list-windows"
import { findWindow } from "./public/find-window"
import { setWindowOption } from "./public/set-window-option"
import { setPaneOption } from "./public/set-pane-option"
import { setSessionOption } from "./public/set-session-option"
import { ensureSession } from "./public/ensure-session"
import { sessionExists } from "./public/session-exists"
import { renameSession } from "./public/rename-session"

// ── Re-exports ───────────────────────────────────────────────────────

export type { TmuxWindow, SplitPaneOptions, CreateWindowOptions } from "./types"
export { type TmuxError } from "./errors"

// ── Service ──────────────────────────────────────────────────────────

const make = Effect.gen(function* () {
  const shell = yield* ShellService

  const ctx = Context.empty().pipe(
    Context.add(ShellService, shell),
  )
  const inject = mkContextInjector(ctx, "Tmux")

  return {
    isInsideTmux,
    currentSession: inject(currentSession),
    createWindow: inject(createWindow),
    splitPane: inject(splitPane),
    sendKeys: inject(sendKeys),
    selectPane: inject(selectPane),
    switchWindow: inject(switchWindow),
    killWindow: inject(killWindow),
    listWindows: inject(listWindows),
    findWindow: inject(findWindow),
    setWindowOption: inject(setWindowOption),
    setPaneOption: inject(setPaneOption),
    setSessionOption: inject(setSessionOption),
    ensureSession: inject(ensureSession),
    sessionExists: inject(sessionExists),
    renameSession: inject(renameSession),
  }
})

export type TmuxServiceShape = Effect.Effect.Success<typeof make>

export class TmuxService extends Context.Tag("TmuxService")<
  TmuxService,
  TmuxServiceShape
>() {}

export const TmuxLive = Layer.effect(TmuxService, make)
