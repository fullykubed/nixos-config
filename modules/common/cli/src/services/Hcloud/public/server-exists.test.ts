import { describe, it, expect } from "bun:test"
import { Context, Effect } from "effect"
import { HttpClient } from "@effect/platform"
import { serverExists } from "./server-exists"
import { mockHttp, failHttp, server1, defaultHcloudConfig } from "../test-helpers"
import { ServerId } from "../types"
import { HcloudConfig } from "../config"

const provide = (http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(HttpClient.HttpClient, http),
    Context.add(HcloudConfig, defaultHcloudConfig),
  ))

describe("serverExists", () => {
  it("returns true when server exists by ID", async () => {
    const http = mockHttp(
      Response.json({ server: server1 }),
    )

    const result = await Effect.runPromise(
      serverExists(ServerId(1)).pipe(provide(http))
    )

    expect(result).toBe(true)
  })

  it("returns true when server exists by name", async () => {
    const http = mockHttp(
      Response.json({
        servers: [server1],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      serverExists("builder-1").pipe(provide(http))
    )

    expect(result).toBe(true)
  })

  it("returns false when server not found", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Server not found" } }), { status: 404 }),
    )

    const result = await Effect.runPromise(
      serverExists(ServerId(999)).pipe(provide(http))
    )

    expect(result).toBe(false)
  })

  it("returns false on API error", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Internal server error" } }), { status: 500 }),
    )

    const result = await Effect.runPromise(
      serverExists(ServerId(1)).pipe(provide(http))
    )

    expect(result).toBe(false)
  })

  it("returns false on network error", async () => {
    const result = await Effect.runPromise(
      serverExists(ServerId(1)).pipe(provide(failHttp))
    )

    expect(result).toBe(false)
  })
})
