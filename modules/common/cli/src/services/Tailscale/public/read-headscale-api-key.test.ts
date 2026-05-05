import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { FileSystem } from "@effect/platform"
import { readHeadscaleApiKey } from "./read-headscale-api-key"

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
    return (exit.cause.error as { _tag?: string })._tag
  }
}

const mockFs = (content: string) => FileSystem.FileSystem.of({
  readFileString: () => Effect.succeed(content),
} as any)

const failingFs = FileSystem.FileSystem.of({
  readFileString: () => Effect.fail(new Error("ENOENT")),
} as any)

describe("readHeadscaleApiKey", () => {
  it("returns trimmed API key on success", async () => {
    const result = await Effect.runPromise(
      readHeadscaleApiKey().pipe(
        Effect.provideService(FileSystem.FileSystem, mockFs("my-api-key-123\n"))
      )
    )
    expect(result).toBe("my-api-key-123")
  })

  it("trims whitespace from key", async () => {
    const result = await Effect.runPromise(
      readHeadscaleApiKey().pipe(
        Effect.provideService(FileSystem.FileSystem, mockFs("  spaced-key  \n"))
      )
    )
    expect(result).toBe("spaced-key")
  })

  it("fails with HeadscalePreAuthError when file not found", async () => {
    const exit = await Effect.runPromiseExit(
      readHeadscaleApiKey().pipe(
        Effect.provideService(FileSystem.FileSystem, failingFs)
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("HeadscalePreAuthError")
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { message: string }
      expect(error.message).toContain("headscale API key")
    }
  })
})
