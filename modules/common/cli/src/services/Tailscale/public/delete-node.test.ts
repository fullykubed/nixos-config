import { describe, it, expect } from "bun:test"
import { Context, Effect } from "effect"
import { SilentLogger } from "../../../lib/test/logger"
import { FileSystem, HttpClient, HttpClientResponse } from "@effect/platform"
import { deleteNode } from "./delete-node"

const mockFs = FileSystem.FileSystem.of({ readFileString: () => Effect.succeed("test-api-key") } as any)
const noKeyFs = FileSystem.FileSystem.of({ readFileString: () => Effect.fail(new Error("ENOENT")) } as any)

const provide = (fs: FileSystem.FileSystem, http: HttpClient.HttpClient) =>
  <A, E>(effect: Effect.Effect<A, E, any>) =>
    effect.pipe(
      Effect.provide(Context.empty().pipe(
        Context.add(FileSystem.FileSystem, fs),
        Context.add(HttpClient.HttpClient, http),
      )),
      Effect.provide(SilentLogger),
    ) as Effect.Effect<A, E>

describe("deleteNode", () => {
  it("deletes node found by givenName", async () => {
    let callCount = 0
    const http = HttpClient.make((request) => {
      callCount++
      if (callCount === 1) {
        return Effect.succeed(HttpClientResponse.fromWeb(
          request,
          Response.json({
            nodes: [
              { id: "42", givenName: "builder-1", name: "builder-1.tailnet" },
              { id: "43", givenName: "builder-2", name: "builder-2.tailnet" },
            ]
          }),
        ))
      }
      return Effect.succeed(HttpClientResponse.fromWeb(
        request,
        new Response(null, { status: 200 }),
      ))
    })

    await Effect.runPromise(
      deleteNode("builder-1").pipe(provide(mockFs, http))
    )
    expect(callCount).toBe(2)
  })

  it("deletes node found by name field", async () => {
    let callCount = 0
    const http = HttpClient.make((request) => {
      callCount++
      if (callCount === 1) {
        return Effect.succeed(HttpClientResponse.fromWeb(
          request,
          Response.json({
            nodes: [{ id: "50", givenName: "other", name: "builder-1" }]
          }),
        ))
      }
      return Effect.succeed(HttpClientResponse.fromWeb(
        request,
        new Response(null, { status: 200 }),
      ))
    })

    await Effect.runPromise(
      deleteNode("builder-1").pipe(provide(mockFs, http))
    )
    expect(callCount).toBe(2)
  })

  it("logs warning and returns when node not found (idempotent)", async () => {
    let callCount = 0
    const http = HttpClient.make((request) => {
      callCount++
      return Effect.succeed(HttpClientResponse.fromWeb(
        request,
        Response.json({
          nodes: [{ id: "42", givenName: "builder-other", name: "builder-other.tailnet" }]
        }),
      ))
    })

    // Should not throw — just logs a warning and returns
    await Effect.runPromise(
      deleteNode("builder-99").pipe(provide(mockFs, http))
    )
    expect(callCount).toBe(1)
  })

  it("returns gracefully when API key is missing", async () => {
    let callCount = 0
    const http = HttpClient.make(() => {
      callCount++
      return Effect.succeed(HttpClientResponse.fromWeb(
        null as any, // dummy request — never actually called
        new Response(null, { status: 200 }),
      ))
    })

    // Should not throw — just logs warning and returns
    await Effect.runPromise(
      deleteNode("builder-1").pipe(provide(noKeyFs, http))
    )
    // HttpClient should never be called since we don't have an API key
    expect(callCount).toBe(0)
  })

  it("returns gracefully when list API call fails", async () => {
    let callCount = 0
    const http = HttpClient.make((request) => {
      callCount++
      return Effect.succeed(HttpClientResponse.fromWeb(
        request,
        new Response(null, { status: 500 }),
      ))
    })

    // Should not throw — just logs warning and returns
    await Effect.runPromise(
      deleteNode("builder-1").pipe(provide(mockFs, http))
    )
    expect(callCount).toBe(1)
  })

  it("handles empty nodes list", async () => {
    let callCount = 0
    const http = HttpClient.make((request) => {
      callCount++
      return Effect.succeed(HttpClientResponse.fromWeb(
        request,
        Response.json({ nodes: [] }),
      ))
    })

    await Effect.runPromise(
      deleteNode("builder-1").pipe(provide(mockFs, http))
    )
    expect(callCount).toBe(1)
  })

  it("handles failed delete gracefully (logs warning, does not fail)", async () => {
    let callCount = 0
    const http = HttpClient.make((request) => {
      callCount++
      if (callCount === 1) {
        return Effect.succeed(HttpClientResponse.fromWeb(
          request,
          Response.json({
            nodes: [{ id: "42", givenName: "builder-1", name: "builder-1" }]
          }),
        ))
      }
      return Effect.succeed(HttpClientResponse.fromWeb(
        request,
        new Response(null, { status: 500 }),
      ))
    })

    // Should not throw even though delete failed
    await Effect.runPromise(
      deleteNode("builder-1").pipe(provide(mockFs, http))
    )
    expect(callCount).toBe(2)
  })
})
