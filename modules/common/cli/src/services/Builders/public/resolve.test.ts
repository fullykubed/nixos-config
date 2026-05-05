import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { resolve } from "./resolve"

describe("resolve", () => {
  it("normalizes bare number to builder-N", async () => {
    expect(await Effect.runPromise(resolve("1"))).toBe("builder-1")
    expect(await Effect.runPromise(resolve("42"))).toBe("builder-42")
  })

  it("normalizes big-N to big-builder-N", async () => {
    expect(await Effect.runPromise(resolve("big-2"))).toBe("big-builder-2")
    expect(await Effect.runPromise(resolve("big-99"))).toBe("big-builder-99")
  })

  it("passes through full valid names unchanged", async () => {
    expect(await Effect.runPromise(resolve("builder-1"))).toBe("builder-1")
    expect(await Effect.runPromise(resolve("big-builder-3"))).toBe("big-builder-3")
  })

  it("fails with InvalidBuilderNameError for unrecognized names", async () => {
    const exit = await Effect.runPromiseExit(resolve("foo"))
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("InvalidBuilderNameError")
      expect(exit.cause.error.input).toBe("foo")
    }
  })

  it("fails with InvalidBuilderNameError for partial names", async () => {
    const exit = await Effect.runPromiseExit(resolve("builder-"))
    expect(Exit.isFailure(exit)).toBe(true)
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      expect(exit.cause.error._tag).toBe("InvalidBuilderNameError")
    }
  })
})
