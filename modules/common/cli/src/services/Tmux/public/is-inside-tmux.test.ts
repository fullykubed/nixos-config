import { describe, it, expect, beforeEach, afterEach } from "bun:test"
import { Effect } from "effect"
import { isInsideTmux } from "./is-inside-tmux"

describe("isInsideTmux", () => {
  let originalTmux: string | undefined

  beforeEach(() => {
    originalTmux = process.env.TMUX
  })

  afterEach(() => {
    if (originalTmux === undefined) {
      delete process.env.TMUX
    } else {
      process.env.TMUX = originalTmux
    }
  })

  it("returns true when TMUX environment variable is set", async () => {
    process.env.TMUX = "/tmp/tmux-1000/default,1234,0"

    const result = await Effect.runPromise(isInsideTmux())
    expect(result).toBe(true)
  })

  it("returns false when TMUX environment variable is not set", async () => {
    delete process.env.TMUX

    const result = await Effect.runPromise(isInsideTmux())
    expect(result).toBe(false)
  })

  it("returns false when TMUX environment variable is empty", async () => {
    process.env.TMUX = ""

    const result = await Effect.runPromise(isInsideTmux())
    expect(result).toBe(false)
  })
})