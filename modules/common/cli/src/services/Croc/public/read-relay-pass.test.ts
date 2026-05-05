import { describe, it, expect } from "bun:test"
import { Effect, Exit } from "effect"
import { FileSystem } from "@effect/platform"
import { readRelayPass } from "./read-relay-pass"

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
    return (exit.cause.error as { _tag?: string })._tag
  }
}

describe("readRelayPass", () => {
  it("returns trimmed password on success", async () => {
    const fs = FileSystem.FileSystem.of({
      readFileString: () => Effect.succeed("my-relay-password\n"),
    } as any)

    const result = await Effect.runPromise(
      readRelayPass().pipe(Effect.provideService(FileSystem.FileSystem, fs))
    )
    expect(result).toBe("my-relay-password")
  })

  it("trims whitespace from password", async () => {
    const fs = FileSystem.FileSystem.of({
      readFileString: () => Effect.succeed("  pass-with-spaces  \n"),
    } as any)

    const result = await Effect.runPromise(
      readRelayPass().pipe(Effect.provideService(FileSystem.FileSystem, fs))
    )
    expect(result).toBe("pass-with-spaces")
  })

  it("fails with CrocRelayPassError when file not found", async () => {
    const fs = FileSystem.FileSystem.of({
      readFileString: () => Effect.fail(new Error("ENOENT")),
    } as any)

    const exit = await Effect.runPromiseExit(
      readRelayPass().pipe(Effect.provideService(FileSystem.FileSystem, fs))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("CrocRelayPassError")
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { path: string; message: string }
      expect(error.path).toContain("croc-relay-password")
      expect(error.message).toContain("croc relay password")
    }
  })
})
