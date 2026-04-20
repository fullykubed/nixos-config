import { describe, it, expect, afterEach } from "bun:test"

const RESET = "\x1b[0m"

describe("colorize", () => {
  const originalIsTTY = process.stdout.isTTY

  afterEach(() => {
    Object.defineProperty(process.stdout, "isTTY", { value: originalIsTTY, writable: true })
  })

  it("returns plain text when not a TTY", async () => {
    Object.defineProperty(process.stdout, "isTTY", { value: false, writable: true })
    // Re-import to get fresh module evaluation isn't needed here since
    // colorize checks isTTY at call time, not at import time
    const { colorize } = await import("./colorize")
    expect(colorize("hello", "OK")).toBe("hello")
    expect(colorize("hello", "FAILED")).toBe("hello")
    expect(colorize("hello", "SKIPPED")).toBe("hello")
    expect(colorize("hello", "WARNING")).toBe("hello")
  })

  it("wraps text with green for OK status in TTY", async () => {
    Object.defineProperty(process.stdout, "isTTY", { value: true, writable: true })
    const { colorize } = await import("./colorize")
    expect(colorize("pass", "OK")).toBe(`${Bun.color("green", "ansi")}pass${RESET}`)
  })

  it("wraps text with red for FAILED status in TTY", async () => {
    Object.defineProperty(process.stdout, "isTTY", { value: true, writable: true })
    const { colorize } = await import("./colorize")
    expect(colorize("fail", "FAILED")).toBe(`${Bun.color("red", "ansi")}fail${RESET}`)
  })

  it("wraps text with yellow for SKIPPED status in TTY", async () => {
    Object.defineProperty(process.stdout, "isTTY", { value: true, writable: true })
    const { colorize } = await import("./colorize")
    expect(colorize("skip", "SKIPPED")).toBe(`${Bun.color("yellow", "ansi")}skip${RESET}`)
  })

  it("wraps text with yellow for WARNING status in TTY", async () => {
    Object.defineProperty(process.stdout, "isTTY", { value: true, writable: true })
    const { colorize } = await import("./colorize")
    expect(colorize("warn", "WARNING")).toBe(`${Bun.color("yellow", "ansi")}warn${RESET}`)
  })
})
