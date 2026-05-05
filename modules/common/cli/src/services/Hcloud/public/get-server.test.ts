import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { HttpClient } from "@effect/platform"
import { getServer } from "./get-server"
import { mockHttp, failHttp, server1, defaultHcloudConfig } from "../helpers.test"
import { ServerId } from "../types"
import { HcloudConfig } from "../config"

const provide = (http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(HttpClient.HttpClient, http),
    Context.add(HcloudConfig, defaultHcloudConfig),
  ))

describe("getServer", () => {
  it("gets server by ID", async () => {
    const http = mockHttp(
      Response.json({ server: server1 }),
    )

    const result = await Effect.runPromise(
      getServer(ServerId(1)).pipe(provide(http))
    )

    expect(result).toEqual(server1)
  })

  it("gets server by name via list", async () => {
    const http = mockHttp(
      Response.json({
        servers: [server1],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromise(
      getServer("builder-1").pipe(provide(http))
    )

    expect(result).toEqual(server1)
  })

  it("fails with HcloudServerNotFound when server not found by ID", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Server not found" } }), { status: 404 }),
    )

    const result = await Effect.runPromiseExit(
      getServer(ServerId(999)).pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudServerNotFound")
      expect((result.cause.error as { name: string }).name).toBe("999")
    }
  })

  it("fails with HcloudServerNotFound when server not found by name", async () => {
    const http = mockHttp(
      Response.json({
        servers: [],
        meta: { pagination: { next_page: null } },
      }),
    )

    const result = await Effect.runPromiseExit(
      getServer("nonexistent").pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudServerNotFound")
      expect((result.cause.error as { name: string }).name).toBe("nonexistent")
    }
  })

  it("fails with HcloudGetServerError on API error", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Internal server error" } }), { status: 500 }),
    )

    const result = await Effect.runPromiseExit(
      getServer(ServerId(1)).pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudGetServerError")
      expect((result.cause.error as { name: string }).name).toBe("1")
      expect((result.cause.error as { message: string }).message).toBe("Internal server error")
    }
  })

  it("fails with HcloudGetServerError on network error", async () => {
    const result = await Effect.runPromiseExit(
      getServer(ServerId(1)).pipe(provide(failHttp))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudGetServerError")
      expect((result.cause.error as { name: string }).name).toBe("1")
      expect((result.cause.error as { message: string }).message).toBe("Request failed")
    }
  })
})
