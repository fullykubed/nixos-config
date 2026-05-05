import { afterAll, afterEach, beforeAll, describe, expect, it } from "bun:test"
import { Effect, Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { SilentLogger } from "../../../lib/test/logger"
import { ShellService } from "../../Shell"
import { TmuxLive } from "../../Tmux"
import { WINDOW_PREFIX } from "../../Tmux/config"
import { listWindows } from "../../Tmux/public/list-windows"
import { killWindow } from "../../Tmux/public/kill-window"
import { makeIsolatedTmuxShell } from "../../Tmux/integration-tests/setup.test"
import { createWindow } from "../internal/create-window"
import { BranchName, WorktreePath } from "../../Git"
import { WorktreeId } from "../types"

const testId = () => WorktreeId(crypto.randomUUID())

const socket = `j-panes-test-${process.pid}`

const TestLayer = TmuxLive.pipe(
  Layer.provideMerge(makeIsolatedTmuxShell(socket)),
  Layer.provideMerge(BunContext.layer),
  Layer.merge(SilentLogger),
)

const run = (effect: any): Promise<any> =>
  effect.pipe(Effect.provide(TestLayer), Effect.runPromise) as Promise<any>

const tmux = (...args: string[]) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const { stdout } = yield* shell.exec("tmux", args)
    return stdout.trim()
  })

const countPanes = (windowId: string) =>
  run(tmux("list-panes", "-t", windowId, "-F", "#{pane_index} #{pane_active}"))
    .then((output: any) =>
      output.split("\n").filter(Boolean).map((line: string) => {
        const [index, active] = line.split(" ")
        return { index: Number(index), active: active === "1" }
      }),
    )

// Large terminal so splits don't fail with "no space for new pane"
beforeAll(() => run(tmux("new-session", "-d", "-s", "test", "-x", "200", "-y", "50")))

afterAll(() =>
  run(tmux("kill-server")).catch(() => {
    // Server may already be dead
  }),
)

describe("createWindow integration", () => {
  let lastWindowId: string | null = null

  afterEach(async () => {
    if (lastWindowId) {
      await run(killWindow(lastWindowId).pipe(Effect.ignore))
      lastWindowId = null
    }
  })

  it("creates an empty window when panes is empty", async () => {
    const windowId = await run(createWindow(BranchName("tmp"), WorktreePath("/tmp"), [], testId()))
    lastWindowId = windowId

    const windows = await run(listWindows())
    const found = windows.find((w: any) => w.id === windowId)
    expect(found).toBeDefined()
    expect(found!.name).toBe(`${WINDOW_PREFIX}tmp`)
  })

  it("pane survives after command exits (runs in user shell)", async () => {
    const windowId = await run(createWindow(BranchName("tmp"), WorktreePath("/tmp"), [
      { command: "echo hello" },
    ], testId()))
    lastWindowId = windowId

    // Give the echo command time to execute and exit
    await Bun.sleep(200)

    // Pane should still exist because the shell stays open
    const panes = await countPanes(windowId)
    expect(panes.length).toBe(1)
  })

  it("creates multiple panes with splits", async () => {
    const windowId = await run(createWindow(BranchName("tmp"), WorktreePath("/tmp"), [
      { command: "echo pane0" },
      { command: "echo pane1", split: "vertical" },
      { split: "horizontal" },
    ], testId()))
    lastWindowId = windowId

    await Bun.sleep(200)

    const panes = await countPanes(windowId)
    expect(panes.length).toBe(3)
  })

  it("focuses the pane with focus: true", async () => {
    const windowId = await run(createWindow(BranchName("tmp"), WorktreePath("/tmp"), [
      { command: "echo first" },
      { command: "echo second", split: "vertical", focus: true },
      { split: "horizontal" },
    ], testId()))
    lastWindowId = windowId

    const panes = await countPanes(windowId)
    expect(panes.length).toBe(3)
    const activePane = panes.find((p: any) => p.active)
    expect(activePane).toBeDefined()
    expect(activePane!.index).toBe(1)
  })

  it("focuses pane 0 by default (no focus: true set)", async () => {
    const windowId = await run(createWindow(BranchName("tmp"), WorktreePath("/tmp"), [
      { command: "echo first" },
      { command: "echo second", split: "vertical" },
    ], testId()))
    lastWindowId = windowId

    const panes = await countPanes(windowId)
    const activePane = panes.find((p: any) => p.active)
    expect(activePane).toBeDefined()
    expect(activePane!.index).toBe(0)
  })

  it("applies percentage to split pane", async () => {
    const windowId = await run(createWindow(BranchName("tmp"), WorktreePath("/tmp"), [
      { command: "echo main" },
      { command: "echo side", split: "vertical", percentage: 30 },
    ], testId()))
    lastWindowId = windowId

    const panes = await countPanes(windowId)
    expect(panes.length).toBe(2)
  })

  it("uses the default pane layout from config schema", async () => {
    const windowId = await run(createWindow(BranchName("tmp"), WorktreePath("/tmp"), [
      { command: "echo editor" },
      { command: "echo shell", split: "vertical", percentage: 33, focus: true },
      { split: "horizontal" },
    ], testId()))
    lastWindowId = windowId

    const panes = await countPanes(windowId)
    expect(panes.length).toBe(3)

    const activePane = panes.find((p: any) => p.active)
    expect(activePane).toBeDefined()
    expect(activePane!.index).toBe(1)
  })

  it("names the window after the worktree basename", async () => {
    const windowId = await run(createWindow(BranchName("feature-branch"), WorktreePath("/home/user/repo/feature-branch"), [], testId()))
    lastWindowId = windowId

    const windows = await run(listWindows())
    const found = windows.find((w: any) => w.id === windowId)
    expect(found).toBeDefined()
    expect(found!.name).toBe(`${WINDOW_PREFIX}feature-branch`)
  })
})
