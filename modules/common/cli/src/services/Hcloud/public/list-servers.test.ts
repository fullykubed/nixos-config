import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { HttpClient } from "@effect/platform"
import { listServers } from "./list-servers"
import { mockHttp, failHttp, server1, server2, defaultHcloudConfig } from "../helpers.test"
import { HcloudConfig } from "../config"

const provide = (http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(HttpClient.HttpClient, http),
    Context.add(HcloudConfig, defaultHcloudConfig),
  ))

describe("listServers", () => {
  it("returns empty list when no servers exist", async () => {
    const http = mockHttp(
      Response.json({
        servers: [],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      listServers().pipe(provide(http))
    )

    expect(result).toEqual([])
  })

  it("returns servers from single page", async () => {
    const http = mockHttp(
      Response.json({
        servers: [server1, server2],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      listServers().pipe(provide(http))
    )

    expect(result).toEqual([server1, server2])
  })

  it("handles pagination correctly", async () => {
    const http = mockHttp(
      Response.json({
        servers: [server1],
        meta: { pagination: { next_page: 2 } },
      }),
      Response.json({
        servers: [server2],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      listServers().pipe(provide(http))
    )

    expect(result).toEqual([server1, server2])
  })

  it("applies name filter", async () => {
    const http = mockHttp(
      Response.json({
        servers: [server1],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      listServers({ name: "builder-1" }).pipe(provide(http))
    )

    expect(result).toEqual([server1])
  })

  it("applies status filter", async () => {
    const http = mockHttp(
      Response.json({
        servers: [server1, server2],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      listServers({ status: "running" }).pipe(provide(http))
    )

    expect(result).toEqual([server1, server2])
  })

  it("applies labels filter", async () => {
    const http = mockHttp(
      Response.json({
        servers: [server2],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      listServers({ labels: { env: "test" } }).pipe(provide(http))
    )

    expect(result).toEqual([server2])
  })

  it("fails with HcloudListServersError on HTTP error", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Internal server error" } }), { status: 500 }),
    )

    const result = await Effect.runPromiseExit(
      listServers().pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudListServersError")
      expect((result.cause.error as { message: string }).message).toBe("HTTP 500")
    }
  })

  it("fails with HcloudListServersError on network error", async () => {
    const result = await Effect.runPromiseExit(
      listServers().pipe(provide(failHttp))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudListServersError")
      expect((result.cause.error as { message: string }).message).toBe("Request failed")
    }
  })
})
