import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit, Fiber, TestClock, TestContext } from "effect"
import { HttpClient, HttpClientResponse } from "@effect/platform"
import { createServer } from "./create-server"
import { mockHttp, failHttp, server1, defaultHcloudConfig } from "../test-helpers"
import type { Server, CreateServerOptions } from "../types"
import { HcloudConfig } from "../config"

const provide = (http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(HttpClient.HttpClient, http),
    Context.add(HcloudConfig, defaultHcloudConfig),
  ))

describe("createServer", () => {
  it("creates server with minimal options", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ server: server1 }), { status: 201 }),
    )

    const opts: CreateServerOptions = {
      name: "builder-1",
      type: "cpx21",
      location: "fsn1",
      image: "ubuntu-20.04",
    }

    const result = await Effect.runPromise(
      createServer(opts).pipe(provide(http))
    )

    expect(result).toEqual(server1)
  })

  it("creates server with all options", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ server: server1 }), { status: 201 }),
    )

    const opts: CreateServerOptions = {
      name: "builder-1",
      type: "cpx21",
      location: "fsn1",
      image: "ubuntu-20.04",
      sshKeys: ["key1", "key2"],
      userData: "#!/bin/bash\necho hello",
      volumes: [200, 201],
      labels: { env: "test", purpose: "builder" },
    }

    const result = await Effect.runPromise(
      createServer(opts).pipe(provide(http))
    )

    expect(result).toEqual(server1)
  })

  it("fails with HcloudCreateServerError on HTTP error", async () => {
    const http = mockHttp(
      new Response(JSON.stringify({ error: { message: "Invalid server type" } }), { status: 400 }),
    )

    const opts: CreateServerOptions = {
      name: "builder-1",
      type: "invalid-type",
      location: "fsn1",
      image: "ubuntu-20.04",
    }

    const result = await Effect.runPromiseExit(
      createServer(opts).pipe(provide(http))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudCreateServerError")
      expect((result.cause.error as { name: string }).name).toBe("builder-1")
      expect((result.cause.error as { message: string }).message).toBe("Invalid server type")
    }
  })

  it("fails with HcloudCreateServerError on network error", async () => {
    const opts: CreateServerOptions = {
      name: "builder-1",
      type: "cpx21",
      location: "fsn1",
      image: "ubuntu-20.04",
    }

    const result = await Effect.runPromiseExit(
      createServer(opts).pipe(provide(failHttp))
    )

    expect(Exit.isFailure(result)).toBe(true)
    if (Exit.isFailure(result) && result.cause._tag === "Fail") {
      expect(result.cause.error._tag).toBe("HcloudCreateServerError")
      expect((result.cause.error as { name: string }).name).toBe("builder-1")
      expect((result.cause.error as { message: string }).message).toBe("Request failed")
    }
  })

  it("returns immediately when waitForRunning is false", async () => {
    const startingServer: Server = { ...server1, status: "starting" }
    const http = mockHttp(
      new Response(JSON.stringify({ server: startingServer }), { status: 201 }),
    )

    const result = await Effect.runPromise(
      createServer({
        name: "builder-1", type: "cpx62", location: "fsn1", image: 100,
      }).pipe(provide(http))
    )

    expect(result.status).toBe("starting")
  })

  it("polls until server is running when waitForRunning is true", async () => {
    const startingServer: Server = { ...server1, status: "starting" }
    const runningServer: Server = { ...server1, status: "running" }
    let pollCount = 0

    const http = HttpClient.make((request) => {
      const isPost = request.method === "POST"
      if (isPost) {
        return Effect.succeed(
          HttpClientResponse.fromWeb(
            request,
            new Response(JSON.stringify({ server: startingServer }), {
              status: 201,
              headers: { "Content-Type": "application/json" },
            })
          )
        )
      }
      // GET poll — return running on 2nd poll
      pollCount++
      const server = pollCount >= 2 ? runningServer : startingServer
      return Effect.succeed(
        HttpClientResponse.fromWeb(
          request,
          new Response(JSON.stringify({ server }), {
            status: 200,
            headers: { "Content-Type": "application/json" },
          })
        )
      )
    })

    const program = Effect.gen(function* () {
      const fiber = yield* createServer({
        name: "builder-1", type: "cpx62", location: "fsn1", image: 100,
        waitForRunning: true,
      }).pipe(
        provide(http),
        Effect.fork,
      )

      // Advance past 2 polling intervals (5s each)
      yield* TestClock.adjust("5 seconds")
      yield* TestClock.adjust("5 seconds")

      return yield* Fiber.join(fiber)
    }).pipe(
      Effect.provide(TestContext.TestContext)
    )

    const result = await Effect.runPromise(program)
    expect(result.status).toBe("running")
    expect(pollCount).toBe(2)
  })
})
