import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit, Fiber, TestClock, TestContext } from "effect"
import { HttpClient, HttpClientError, HttpClientResponse } from "@effect/platform"
import { deleteServer } from "./delete-server"
import { mockHttp, server1, defaultHcloudConfig } from "../test-helpers"
import type { Server } from "../types"
import { HcloudConfig } from "../config"

const provide = (http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(HttpClient.HttpClient, http),
    Context.add(HcloudConfig, defaultHcloudConfig),
  ))

describe("deleteServer", () => {
  it("deletes server without waiting", async () => {
    const http = mockHttp(
      // getServer -> listServers response
      Response.json({
        servers: [server1],
        meta: { pagination: { next_page: null } },
      }),
      // delete response
      new Response(null, { status: 204 }),
    )

    await Effect.runPromise(
      deleteServer("builder-1").pipe(provide(http))
    )
  })

  it("skips delete if server is already deleting", async () => {
    const deletingServer = { ...server1, status: "deleting" as const }

    const http = mockHttp(
      // getServer -> listServers response
      Response.json({
        servers: [deletingServer],
        meta: { pagination: { next_page: null } },
      }),
    )

    await Effect.runPromise(
      deleteServer("builder-1").pipe(provide(http))
    )
  })

  it("fails with HcloudServerNotFound when server doesn't exist", async () => {
    const http = mockHttp(
      Response.json({
        servers: [],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromiseExit(
      deleteServer("nonexistent").pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudServerNotFound")
      expect((result.cause.error as { name: string }).name).toBe("nonexistent")
    }
  })

  it("fails with HcloudDeleteServerError on delete API error", async () => {
    const http = mockHttp(
      // getServer -> listServers response
      Response.json({
        servers: [server1],
        meta: { pagination: { next_page: null } },
      }),
      // delete call error
      new Response(JSON.stringify({ error: { message: "Internal server error" } }), { status: 500 }),
    )

    const result = await Effect.runPromiseExit(
      deleteServer("builder-1").pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudDeleteServerError")
      expect((result.cause.error as { name: string }).name).toBe("builder-1")
      expect((result.cause.error as { message: string }).message).toBe("Internal server error")
    }
  })

  it("fails with HcloudDeleteServerError on network error", async () => {
    // First call succeeds (getServer), second call fails (delete)
    // For this we need a custom mock that succeeds first, then fails
    let callCount = 0
    const http = HttpClient.make((request) => {
      callCount++
      if (callCount === 1) {
        return Effect.succeed(HttpClientResponse.fromWeb(
          request,
          Response.json({
            servers: [server1],
            meta: { pagination: { next_page: null } },
          }),
        ))
      }
      return Effect.fail(new HttpClientError.RequestError({
        request,
        reason: "Transport",
        cause: new Error("Network error"),
      }))
    })

    const result = await Effect.runPromiseExit(
      deleteServer("builder-1").pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudDeleteServerError")
      expect((result.cause.error as { name: string }).name).toBe("builder-1")
      expect((result.cause.error as { message: string }).message).toBe("Request failed")
    }
  })

  it("returns immediately without polling when wait is not set", async () => {
    const http = mockHttp(
      // getServer -> listServers response
      Response.json({
        servers: [server1],
        meta: { pagination: { next_page: null } },
      }),
      // delete response
      Response.json({ action: { id: 1, status: "running" } }),
    )

    await Effect.runPromise(
      deleteServer("builder-1").pipe(provide(http))
    )
  })

  it("polls until server is gone when wait is true", async () => {
    const deletingServer: Server = { ...server1, status: "deleting" as const }
    let pollCount = 0

    const http = HttpClient.make((request) => {
      if (request.method === "DELETE") {
        return Effect.succeed(HttpClientResponse.fromWeb(
          request,
          Response.json({ action: { id: 1, status: "running" } }),
        ))
      }
      // GET requests — return server for first 2 polls, then empty (gone)
      pollCount++
      if (pollCount <= 2) {
        return Effect.succeed(HttpClientResponse.fromWeb(
          request,
          Response.json({
            servers: [deletingServer],
            meta: { pagination: { next_page: null } },
          }),
        ))
      }
      return Effect.succeed(HttpClientResponse.fromWeb(
        request,
        Response.json({
          servers: [],
          meta: { pagination: { next_page: null } },
        }),
      ))
    })

    const program = Effect.gen(function* () {
      const fiber = yield* deleteServer("builder-1", { wait: true }).pipe(
        provide(http),
        Effect.fork,
      )

      // Advance past polling intervals (3s each)
      yield* TestClock.adjust("3 seconds")
      yield* TestClock.adjust("3 seconds")
      yield* TestClock.adjust("3 seconds")

      return yield* Fiber.join(fiber)
    }).pipe(
      Effect.provide(TestContext.TestContext)
    )

    await Effect.runPromise(program)
    expect(pollCount).toBe(3)
  })
})
