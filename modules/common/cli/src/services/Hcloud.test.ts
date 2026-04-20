import { describe, it, expect, beforeAll, afterAll, beforeEach, afterEach, mock } from "bun:test"
import { Effect, Exit, Fiber, Layer, TestClock, TestContext } from "effect"
import { BunContext } from "@effect/platform-bun"
import {
  HcloudService,
  HcloudLive,
  ServerId,
  ImageId,
  VolumeId,
  type Server,
  type Image,
  type Volume,
} from "./Hcloud"

// ── Fixtures ────────────────────────────────────────────────────────

const server1: Server = {
  id: ServerId(1),
  name: "builder-1",
  status: "running",
  public_net: { ipv4: { ip: "1.2.3.4" } },
  server_type: { name: "cpx62", description: "CPX 62" },
  created: "2024-01-01T00:00:00Z",
  labels: {},
}

const server2: Server = {
  id: ServerId(2),
  name: "builder-2",
  status: "running",
  public_net: { ipv4: { ip: "5.6.7.8" } },
  server_type: { name: "cpx62", description: "CPX 62" },
  created: "2024-01-02T00:00:00Z",
  labels: { env: "test" },
}

const image1: Image = {
  id: ImageId(100),
  name: "builder-snap-1",
  description: "Builder snapshot",
  type: "snapshot",
  status: "available",
  architecture: "x86",
  os_flavor: "unknown",
  os_version: null,
  rapid_deploy: false,
  created: "2024-01-01T00:00:00Z",
  created_from: { id: 1, name: "builder-1" },
  bound_to: null,
  deleted: null,
  deprecated: null,
  labels: { type: "builder" },
  protection: { delete: false },
}

const volume1: Volume = {
  id: VolumeId(200),
  name: "ccache-builder-1",
  size: 50,
  location: {
    id: 1, name: "fsn1", description: "Falkenstein DC Park 1",
    country: "DE", city: "Falkenstein", latitude: 50.47612, longitude: 12.37044,
    network_zone: "eu-central",
  },
  labels: { "builder-ccache": "true" },
  linux_device: "/dev/sdb",
  protection: { delete: false },
  server: 1,
  created: "2024-01-01T00:00:00Z",
}

// ── Test Layer ───────────────────────────────────────────────────────

const TestLayer = HcloudLive.pipe(Layer.provide(BunContext.layer))

// ── Token setup ─────────────────────────────────────────────────────

const originalToken = process.env.HCLOUD_TOKEN
beforeAll(() => { process.env.HCLOUD_TOKEN = "test-token-12345" })
afterAll(() => {
  if (originalToken !== undefined) {
    process.env.HCLOUD_TOKEN = originalToken
  } else {
    delete process.env.HCLOUD_TOKEN
  }
})

// ── Helper ──────────────────────────────────────────────────────────

function extractFailureTag(exit: Exit.Exit<any, any>): string | undefined {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return (cause.error)?._tag
  return undefined
}

function extractFailure(exit: Exit.Exit<any, any>): any {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return cause.error
  return undefined
}

// ── Tests ───────────────────────────────────────────────────────────

describe("HcloudService", () => {
  // ── listServers ─────────────────────────────────────────────────
  describe("listServers", () => {
    let originalFetch: typeof globalThis.fetch

    beforeEach(() => { originalFetch = globalThis.fetch })
    afterEach(() => { globalThis.fetch = originalFetch })

    const layer = TestLayer

    const wrapPage = (servers: Server[], nextPage: number | null = null) => ({
      servers,
      meta: { pagination: { next_page: nextPage } },
    })

    it("parses JSON into Server[]", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapPage([server1, server2])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.listServers()),
          Effect.provide(layer)
        )
      )
      expect(result).toHaveLength(2)
      expect(result[0]!.name).toBe("builder-1")
      expect(result[1]!.name).toBe("builder-2")
    })

    it("returns empty array when no servers exist", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapPage([])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.listServers()),
          Effect.provide(layer)
        )
      )
      expect(result).toHaveLength(0)
    })

    it("paginates across multiple pages", async () => {
      let callCount = 0
      globalThis.fetch = mock(async (url: any) => {
        callCount++
        const urlStr = typeof url === "string" ? url : url.toString()
        if (urlStr.includes("page=1")) {
          return new Response(JSON.stringify(wrapPage([server1], 2)), {
            status: 200,
            headers: { "Content-Type": "application/json" },
          })
        }
        return new Response(JSON.stringify(wrapPage([server2])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.listServers()),
          Effect.provide(layer)
        )
      )
      expect(result).toHaveLength(2)
      expect(result[0]!.name).toBe("builder-1")
      expect(result[1]!.name).toBe("builder-2")
      expect(callCount).toBe(2)
    })

    it("fails with HcloudListServersError on API error", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify({ error: { message: "unauthorized" } }), {
          status: 401,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.listServers()),
          Effect.provide(layer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudListServersError")
      expect(extractFailure(exit).message).toBe("HTTP 401")
    })

    it("fails with HcloudListServersError when fetch throws", async () => {
      globalThis.fetch = mock(async () => {
        throw new Error("network unreachable")
      }) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.listServers()),
          Effect.provide(layer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudListServersError")
      expect(extractFailure(exit).message).toBe("Request failed")
      expect(extractFailure(exit).cause).toBeInstanceOf(Error)
    })

    it("passes status filter as query parameter", async () => {
      let capturedUrl = ""
      globalThis.fetch = mock(async (url: any) => {
        capturedUrl = typeof url === "string" ? url : url.toString()
        return new Response(JSON.stringify(wrapPage([])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.listServers({ status: "running" })),
          Effect.provide(layer)
        )
      )
      expect(capturedUrl).toContain("status=running")
    })

    it("passes label selector as query parameter", async () => {
      let capturedUrl = ""
      globalThis.fetch = mock(async (url: any) => {
        capturedUrl = typeof url === "string" ? url : url.toString()
        return new Response(JSON.stringify(wrapPage([])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.listServers({ labels: { type: "builder", env: "prod" } })),
          Effect.provide(layer)
        )
      )
      expect(capturedUrl).toContain("label_selector=")
      expect(capturedUrl).toContain("type%3Dbuilder")
      expect(capturedUrl).toContain("env%3Dprod")
    })
  })

  // ── getServer ───────────────────────────────────────────────────
  describe("getServer", () => {
    let originalFetch: typeof globalThis.fetch

    beforeEach(() => { originalFetch = globalThis.fetch })
    afterEach(() => { globalThis.fetch = originalFetch })

    const layer = TestLayer

    const wrapPage = (servers: Server[], nextPage: number | null = null) => ({
      servers,
      meta: { pagination: { next_page: nextPage } },
    })

    it("returns server when found", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapPage([server1])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.getServer("builder-1")),
          Effect.provide(layer)
        )
      )
      expect(result.name).toBe("builder-1")
      expect(result.id).toBe(ServerId(1))
    })

    it("returns correct server when multiple exist", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapPage([server1, server2])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.getServer("builder-2")),
          Effect.provide(layer)
        )
      )
      expect(result.name).toBe("builder-2")
      expect(result.id).toBe(ServerId(2))
      expect(result.public_net.ipv4.ip).toBe("5.6.7.8")
    })

    it("fails with HcloudServerNotFound when not found", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapPage([])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.getServer("nonexistent")),
          Effect.provide(layer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudServerNotFound")
      expect(extractFailure(exit).name).toBe("nonexistent")
    })

    it("fails with HcloudServerNotFound when server list is empty", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapPage([])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.getServer("builder-1")),
          Effect.provide(layer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudServerNotFound")
    })

    it("fetches by ID using GET /v1/servers/{id}", async () => {
      let capturedUrl = ""
      globalThis.fetch = mock(async (url: any) => {
        capturedUrl = typeof url === "string" ? url : url.toString()
        return new Response(JSON.stringify({ server: server1 }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.getServer(ServerId(1))),
          Effect.provide(layer)
        )
      )
      expect(result.name).toBe("builder-1")
      expect(result.id).toBe(ServerId(1))
      expect(capturedUrl).toContain("/v1/servers/1")
    })

    it("fails with HcloudServerNotFound when ID returns 404", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify({ error: { message: "not found" } }), {
          status: 404,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.getServer(ServerId(999))),
          Effect.provide(layer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudServerNotFound")
      expect(extractFailure(exit).name).toBe("999")
    })
  })

  // ── serverExists ──────────────────────────────────────────────
  describe("serverExists", () => {
    let originalFetch: typeof globalThis.fetch

    beforeEach(() => { originalFetch = globalThis.fetch })
    afterEach(() => { globalThis.fetch = originalFetch })

    const wrapPage = (servers: Server[], nextPage: number | null = null) => ({
      servers,
      meta: { pagination: { next_page: nextPage } },
    })

    it("returns true when server exists", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapPage([server1])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.serverExists("builder-1")),
          Effect.provide(TestLayer)
        )
      )
      expect(result).toBe(true)
    })

    it("returns false when server not found", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapPage([])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.serverExists("nonexistent")),
          Effect.provide(TestLayer)
        )
      )
      expect(result).toBe(false)
    })
  })

  // ── createServer ────────────────────────────────────────────────
  describe("createServer", () => {
    let originalFetch: typeof globalThis.fetch

    beforeEach(() => { originalFetch = globalThis.fetch })
    afterEach(() => { globalThis.fetch = originalFetch })

    const layer = TestLayer

    it("sends correct POST body and returns server", async () => {
      const createdServer: Server = { ...server1, status: "starting" }
      let capturedBody: any = null
      let capturedHeaders: any = null

      globalThis.fetch = mock(async (url: any, init: any) => {
        capturedBody = JSON.parse(init.body)
        capturedHeaders = init.headers
        return new Response(JSON.stringify({ server: createdServer }), {
          status: 201,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.createServer({
            name: "builder-1",
            type: "cpx62",
            location: "fsn1",
            image: 100,
            sshKeys: ["my-key"],
            userData: "#cloud-config\ntest: true",
            volumes: [200],
            labels: { builder: "true" },
          })),
          Effect.provide(layer)
        )
      )

      expect(result.name).toBe("builder-1")
      expect(capturedBody.name).toBe("builder-1")
      expect(capturedBody.server_type).toBe("cpx62")
      expect(capturedBody.location).toBe("fsn1")
      expect(capturedBody.image).toBe(100)
      expect(capturedBody.ssh_keys).toEqual(["my-key"])
      expect(capturedBody.user_data).toBe("#cloud-config\ntest: true")
      expect(capturedBody.volumes).toEqual([200])
      expect(capturedBody.labels).toEqual({ builder: "true" })
      expect(capturedHeaders.Authorization).toBe("Bearer test-token-12345")
      expect(capturedHeaders["Content-Type"]).toBe("application/json")
    })

    it("omits optional fields when not provided", async () => {
      let capturedBody: any = null

      globalThis.fetch = mock(async (_url: any, init: any) => {
        capturedBody = JSON.parse(init.body)
        return new Response(JSON.stringify({ server: server1 }), {
          status: 201,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.createServer({
            name: "builder-1",
            type: "cpx62",
            location: "fsn1",
            image: 100,
          })),
          Effect.provide(layer)
        )
      )

      expect(capturedBody.ssh_keys).toBeUndefined()
      expect(capturedBody.user_data).toBeUndefined()
      expect(capturedBody.volumes).toBeUndefined()
      expect(capturedBody.labels).toBeUndefined()
    })

    it("fails with HcloudCreateServerError on API error response", async () => {
      globalThis.fetch = mock(async () => {
        return new Response(
          JSON.stringify({ error: { message: "server limit exceeded", code: "limit_exceeded" } }),
          { status: 403, headers: { "Content-Type": "application/json" } },
        )
      }) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.createServer({
            name: "builder-1", type: "cpx62", location: "fsn1", image: 100,
          })),
          Effect.provide(layer)
        )
      )

      expect(extractFailureTag(exit)).toBe("HcloudCreateServerError")
      expect(extractFailure(exit).message).toContain("server limit exceeded")
    })

    it("fails with HcloudCreateServerError when fetch throws", async () => {
      globalThis.fetch = mock(async () => {
        throw new Error("network unreachable")
      }) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.createServer({
            name: "builder-1", type: "cpx62", location: "fsn1", image: 100,
          })),
          Effect.provide(layer)
        )
      )

      expect(extractFailureTag(exit)).toBe("HcloudCreateServerError")
      expect(extractFailure(exit).message).toBe("Request failed")
      expect(extractFailure(exit).cause).toBeInstanceOf(Error)
    })

    it("returns immediately when waitForRunning is false", async () => {
      const startingServer: Server = { ...server1, status: "starting" }
      globalThis.fetch = mock(async () => {
        return new Response(JSON.stringify({ server: startingServer }), {
          status: 201,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.createServer({
            name: "builder-1", type: "cpx62", location: "fsn1", image: 100,
          })),
          Effect.provide(layer)
        )
      )

      expect(result.status).toBe("starting")
    })

    it("polls until server is running when waitForRunning is true", async () => {
      const startingServer: Server = { ...server1, status: "starting" }
      const runningServer: Server = { ...server1, status: "running" }
      let pollCount = 0

      globalThis.fetch = mock(async (url: any, init: any) => {
        const _urlStr = typeof url === "string" ? url : url.toString()

        if (init?.method === "POST") {
          return new Response(JSON.stringify({ server: startingServer }), {
            status: 201,
            headers: { "Content-Type": "application/json" },
          })
        }
        // GET poll — return running on 2nd poll
        pollCount++
        const server = pollCount >= 2 ? runningServer : startingServer
        return new Response(JSON.stringify({ server }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      const program = Effect.gen(function* () {
        const fiber = yield* HcloudService.pipe(
          Effect.flatMap(svc => svc.createServer({
            name: "builder-1", type: "cpx62", location: "fsn1", image: 100,
            waitForRunning: true,
          })),
          Effect.fork
        )

        // Advance past 2 polling intervals (5s each)
        yield* TestClock.adjust("5 seconds")
        yield* TestClock.adjust("5 seconds")

        return yield* Fiber.join(fiber)
      }).pipe(
        Effect.provide(layer),
        Effect.provide(TestContext.TestContext)
      )

      const result = await Effect.runPromise(program)
      expect(result.status).toBe("running")
      expect(pollCount).toBe(2)
    })
  })

  // ── deleteServer ────────────────────────────────────────────────
  describe("deleteServer", () => {
    let originalFetch: typeof globalThis.fetch

    beforeEach(() => { originalFetch = globalThis.fetch })
    afterEach(() => { globalThis.fetch = originalFetch })

    const layer = TestLayer

    const wrapPage = (servers: Server[], nextPage: number | null = null) => ({
      servers,
      meta: { pagination: { next_page: nextPage } },
    })

    const listResponse = (servers: Server[]) =>
      new Response(JSON.stringify(wrapPage(servers)), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })

    it("succeeds when server exists", async () => {
      globalThis.fetch = mock(async (url: any, init: any) => {
        if (init?.method === "DELETE") {
          return new Response(JSON.stringify({ action: { id: 1, status: "running" } }), {
            status: 200,
            headers: { "Content-Type": "application/json" },
          })
        }
        return listResponse([server1])
      }) as any

      await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.deleteServer("builder-1")),
          Effect.provide(layer)
        )
      )
    })

    it("fails with HcloudServerNotFound when server not found", async () => {
      globalThis.fetch = mock(async () => listResponse([])) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.deleteServer("nonexistent")),
          Effect.provide(layer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudServerNotFound")
      expect(extractFailure(exit).name).toBe("nonexistent")
    })

    it("fails with HcloudDeleteServerError when API returns error", async () => {
      globalThis.fetch = mock(async (_url: any, init: any) => {
        if (init?.method === "DELETE") {
          return new Response(
            JSON.stringify({ error: { message: "server is locked", code: "locked" } }),
            { status: 409, headers: { "Content-Type": "application/json" } },
          )
        }
        return listResponse([server1])
      }) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.deleteServer("builder-1")),
          Effect.provide(layer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudDeleteServerError")
      expect(extractFailure(exit).name).toBe("builder-1")
      expect(extractFailure(exit).message).toContain("server is locked")
    })

    it("fails with HcloudDeleteServerError when delete fetch throws", async () => {
      globalThis.fetch = mock(async (_url: any, init: any) => {
        if (init?.method === "DELETE") {
          throw new Error("network unreachable")
        }
        return listResponse([server1])
      }) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.deleteServer("builder-1")),
          Effect.provide(layer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudDeleteServerError")
      expect(extractFailure(exit).name).toBe("builder-1")
      expect(extractFailure(exit).message).toBe("Request failed")
      expect(extractFailure(exit).cause).toBeInstanceOf(Error)
    })

    it("skips delete when server status is already deleting", async () => {
      const deletingServer: Server = { ...server1, status: "deleting" }
      let deleteRequested = false

      globalThis.fetch = mock(async (_url: any, init: any) => {
        if (init?.method === "DELETE") {
          deleteRequested = true
          return new Response(JSON.stringify({}), { status: 200 })
        }
        return listResponse([deletingServer])
      }) as any

      await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.deleteServer("builder-1")),
          Effect.provide(layer)
        )
      )
      expect(deleteRequested).toBe(false)
    })

    it("polls until server is gone when wait is true", async () => {
      const deletingServer: Server = { ...server1, status: "deleting" }
      let pollCount = 0

      globalThis.fetch = mock(async (_url: any, init: any) => {
        if (init?.method === "DELETE") {
          return new Response(JSON.stringify({ action: { id: 1, status: "running" } }), {
            status: 200,
            headers: { "Content-Type": "application/json" },
          })
        }
        // GET requests — return server for first 2 polls, then 404
        pollCount++
        if (pollCount <= 2) {
          return listResponse([deletingServer])
        }
        return listResponse([])
      }) as any

      const program = Effect.gen(function* () {
        const fiber = yield* HcloudService.pipe(
          Effect.flatMap(svc => svc.deleteServer("builder-1", { wait: true })),
          Effect.fork
        )

        // Advance past polling intervals (3s each)
        yield* TestClock.adjust("3 seconds")
        yield* TestClock.adjust("3 seconds")
        yield* TestClock.adjust("3 seconds")

        return yield* Fiber.join(fiber)
      }).pipe(
        Effect.provide(layer),
        Effect.provide(TestContext.TestContext)
      )

      await Effect.runPromise(program)
      expect(pollCount).toBe(3)
    })

    it("returns immediately without polling when wait is not set", async () => {
      let fetchCount = 0

      globalThis.fetch = mock(async (_url: any, init: any) => {
        fetchCount++
        if (init?.method === "DELETE") {
          return new Response(JSON.stringify({ action: { id: 1, status: "running" } }), {
            status: 200,
            headers: { "Content-Type": "application/json" },
          })
        }
        return listResponse([server1])
      }) as any

      await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.deleteServer("builder-1")),
          Effect.provide(layer)
        )
      )
      // 1 list call (getServer) + 1 DELETE = 2 fetches, no polling
      expect(fetchCount).toBe(2)
    })
  })

  // ── listImages ──────────────────────────────────────────────────
  describe("listImages", () => {
    let originalFetch: typeof globalThis.fetch

    beforeEach(() => { originalFetch = globalThis.fetch })
    afterEach(() => { globalThis.fetch = originalFetch })

    const wrapPage = (images: Image[], nextPage: number | null = null) => ({
      images,
      meta: { pagination: { next_page: nextPage } },
    })

    it("parses JSON into Image[]", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapPage([image1])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.listImages()),
          Effect.provide(TestLayer)
        )
      )
      expect(result).toHaveLength(1)
      expect(result[0]!.id).toBe(ImageId(100))
      expect(result[0]!.type).toBe("snapshot")
    })

    it("returns empty array when no images exist", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapPage([])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.listImages()),
          Effect.provide(TestLayer)
        )
      )
      expect(result).toHaveLength(0)
    })

    it("passes type filter as query parameter", async () => {
      let capturedUrl = ""
      globalThis.fetch = mock(async (url: any) => {
        capturedUrl = typeof url === "string" ? url : url.toString()
        return new Response(JSON.stringify(wrapPage([])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.listImages("snapshot")),
          Effect.provide(TestLayer)
        )
      )
      expect(capturedUrl).toContain("type=snapshot")
    })

    it("passes label selector as query parameter", async () => {
      let capturedUrl = ""
      globalThis.fetch = mock(async (url: any) => {
        capturedUrl = typeof url === "string" ? url : url.toString()
        return new Response(JSON.stringify(wrapPage([])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.listImages(undefined, { type: "builder" })),
          Effect.provide(TestLayer)
        )
      )
      expect(capturedUrl).toContain("label_selector=")
      expect(capturedUrl).toContain("type%3Dbuilder")
    })

    it("fails with HcloudListImagesError on API error", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify({ error: { message: "unauthorized" } }), {
          status: 401,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.listImages()),
          Effect.provide(TestLayer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudListImagesError")
      expect(extractFailure(exit).message).toBe("HTTP 401")
    })
  })

  // ── getImage ───────────────────────────────────────────────────
  describe("getImage", () => {
    let originalFetch: typeof globalThis.fetch

    beforeEach(() => { originalFetch = globalThis.fetch })
    afterEach(() => { globalThis.fetch = originalFetch })

    const wrapPage = (images: Image[], nextPage: number | null = null) => ({
      images,
      meta: { pagination: { next_page: nextPage } },
    })

    it("returns image when found by name", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapPage([image1])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.getImage("builder-snap-1")),
          Effect.provide(TestLayer)
        )
      )
      expect(result.name).toBe("builder-snap-1")
      expect(result.id).toBe(ImageId(100))
    })

    it("fetches by ID using GET /v1/images/{id}", async () => {
      let capturedUrl = ""
      globalThis.fetch = mock(async (url: any) => {
        capturedUrl = typeof url === "string" ? url : url.toString()
        return new Response(JSON.stringify({ image: image1 }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.getImage(ImageId(100))),
          Effect.provide(TestLayer)
        )
      )
      expect(result.name).toBe("builder-snap-1")
      expect(result.id).toBe(ImageId(100))
      expect(capturedUrl).toContain("/v1/images/100")
    })

    it("fails with HcloudImageNotFound when ID returns 404", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify({ error: { message: "not found" } }), {
          status: 404,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.getImage(ImageId(999))),
          Effect.provide(TestLayer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudImageNotFound")
      expect(extractFailure(exit).id).toBe("999")
    })

    it("fails with HcloudImageNotFound when name not found", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapPage([])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.getImage("nonexistent")),
          Effect.provide(TestLayer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudImageNotFound")
      expect(extractFailure(exit).id).toBe("nonexistent")
    })
  })

  // ── imageExists ───────────────────────────────────────────────
  describe("imageExists", () => {
    let originalFetch: typeof globalThis.fetch

    beforeEach(() => { originalFetch = globalThis.fetch })
    afterEach(() => { globalThis.fetch = originalFetch })

    it("returns true when image exists", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify({ image: image1 }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.imageExists(ImageId(100))),
          Effect.provide(TestLayer)
        )
      )
      expect(result).toBe(true)
    })

    it("returns false when image not found", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify({ error: { message: "not found" } }), {
          status: 404,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.imageExists(ImageId(999))),
          Effect.provide(TestLayer)
        )
      )
      expect(result).toBe(false)
    })
  })

  // ── deleteImage ─────────────────────────────────────────────────
  describe("deleteImage", () => {
    let originalFetch: typeof globalThis.fetch

    beforeEach(() => { originalFetch = globalThis.fetch })
    afterEach(() => { globalThis.fetch = originalFetch })

    it("succeeds when image exists (by ID)", async () => {
      globalThis.fetch = mock(async (_url: any, init: any) => {
        if (init?.method === "DELETE") {
          return new Response(null, { status: 204 })
        }
        // GET /v1/images/{id} for getImage
        return new Response(JSON.stringify({ image: image1 }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.deleteImage(ImageId(100))),
          Effect.provide(TestLayer)
        )
      )
    })

    it("fails with HcloudImageNotFound when image not found", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify({ error: { message: "not found" } }), {
          status: 404,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.deleteImage(ImageId(999))),
          Effect.provide(TestLayer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudImageNotFound")
    })

    it("fails with HcloudDeleteImageError when delete API returns error", async () => {
      globalThis.fetch = mock(async (_url: any, init: any) => {
        if (init?.method === "DELETE") {
          return new Response(
            JSON.stringify({ error: { message: "permission denied" } }),
            { status: 403, headers: { "Content-Type": "application/json" } },
          )
        }
        return new Response(JSON.stringify({ image: image1 }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.deleteImage(ImageId(100))),
          Effect.provide(TestLayer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudDeleteImageError")
      expect(extractFailure(exit).message).toContain("permission denied")
    })

    it("accepts string name", async () => {
      const wrapPage = (images: Image[], nextPage: number | null = null) => ({
        images,
        meta: { pagination: { next_page: nextPage } },
      })

      globalThis.fetch = mock(async (_url: any, init: any) => {
        if (init?.method === "DELETE") {
          return new Response(null, { status: 204 })
        }
        // listImages for name-based lookup
        return new Response(JSON.stringify(wrapPage([image1])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.deleteImage("builder-snap-1")),
          Effect.provide(TestLayer)
        )
      )
    })
  })

  // ── listVolumes ─────────────────────────────────────────────────
  describe("listVolumes", () => {
    let originalFetch: typeof globalThis.fetch

    beforeEach(() => { originalFetch = globalThis.fetch })
    afterEach(() => { globalThis.fetch = originalFetch })

    const wrapPage = (volumes: Volume[], nextPage: number | null = null) => ({
      volumes,
      meta: { pagination: { next_page: nextPage } },
    })

    it("parses JSON into Volume[]", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapPage([volume1])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.listVolumes()),
          Effect.provide(TestLayer)
        )
      )
      expect(result).toHaveLength(1)
      expect(result[0]!.name).toBe("ccache-builder-1")
      expect(result[0]!.size).toBe(50)
    })

    it("returns empty array when no volumes exist", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapPage([])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.listVolumes()),
          Effect.provide(TestLayer)
        )
      )
      expect(result).toHaveLength(0)
    })

    it("fails with HcloudListVolumesError on API error", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify({ error: { message: "unauthorized" } }), {
          status: 401,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.listVolumes()),
          Effect.provide(TestLayer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudListVolumesError")
    })
  })

  // ── getVolume ──────────────────────────────────────────────────
  describe("getVolume", () => {
    let originalFetch: typeof globalThis.fetch

    beforeEach(() => { originalFetch = globalThis.fetch })
    afterEach(() => { globalThis.fetch = originalFetch })

    const wrapVolumePage = (volumes: Volume[]) => ({
      volumes,
      meta: { pagination: { next_page: null } },
    })

    it("returns volume when found by name", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapVolumePage([volume1])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.getVolume("ccache-builder-1")),
          Effect.provide(TestLayer)
        )
      )
      expect(result.name).toBe("ccache-builder-1")
      expect(result.id).toBe(VolumeId(200))
    })

    it("fetches by ID using GET /v1/volumes/{id}", async () => {
      let capturedUrl = ""
      globalThis.fetch = mock(async (url: any) => {
        capturedUrl = typeof url === "string" ? url : url.toString()
        return new Response(JSON.stringify({ volume: volume1 }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.getVolume(VolumeId(200))),
          Effect.provide(TestLayer)
        )
      )
      expect(result.name).toBe("ccache-builder-1")
      expect(result.id).toBe(VolumeId(200))
      expect(capturedUrl).toContain("/v1/volumes/200")
    })

    it("fails with HcloudVolumeNotFound when ID returns 404", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify({ error: { message: "not found" } }), {
          status: 404,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.getVolume(VolumeId(999))),
          Effect.provide(TestLayer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudVolumeNotFound")
      expect(extractFailure(exit).name).toBe("999")
    })

    it("fails with HcloudVolumeNotFound when name not found", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapVolumePage([])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.getVolume("nonexistent")),
          Effect.provide(TestLayer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudVolumeNotFound")
      expect(extractFailure(exit).name).toBe("nonexistent")
    })
  })

  // ── volumeExists ──────────────────────────────────────────────
  describe("volumeExists", () => {
    let originalFetch: typeof globalThis.fetch

    beforeEach(() => { originalFetch = globalThis.fetch })
    afterEach(() => { globalThis.fetch = originalFetch })

    const wrapVolumePage = (volumes: Volume[]) => ({
      volumes,
      meta: { pagination: { next_page: null } },
    })

    it("returns true when volume exists", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapVolumePage([volume1])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.volumeExists("ccache-builder-1")),
          Effect.provide(TestLayer)
        )
      )
      expect(result).toBe(true)
    })

    it("returns false when volume not found", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapVolumePage([])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.volumeExists("nonexistent")),
          Effect.provide(TestLayer)
        )
      )
      expect(result).toBe(false)
    })
  })

  // ── createVolume ────────────────────────────────────────────────
  describe("createVolume", () => {
    let originalFetch: typeof globalThis.fetch

    beforeEach(() => { originalFetch = globalThis.fetch })
    afterEach(() => { globalThis.fetch = originalFetch })

    it("sends correct POST body and returns volume", async () => {
      let capturedBody: any = null

      globalThis.fetch = mock(async (_url: any, init: any) => {
        capturedBody = JSON.parse(init.body)
        return new Response(JSON.stringify({ volume: volume1 }), {
          status: 201,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      const result = await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.createVolume({
            name: "ccache-builder-1",
            size: 50,
            location: "fsn1",
            labels: { "builder-ccache": "true" },
            format: "ext4",
          })),
          Effect.provide(TestLayer)
        )
      )
      expect(result.name).toBe("ccache-builder-1")
      expect(result.id).toBe(VolumeId(200))
      expect(capturedBody.name).toBe("ccache-builder-1")
      expect(capturedBody.size).toBe(50)
      expect(capturedBody.location).toBe("fsn1")
      expect(capturedBody.format).toBe("ext4")
      expect(capturedBody.labels).toEqual({ "builder-ccache": "true" })
    })

    it("fails with HcloudCreateVolumeError on API error", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify({ error: { message: "quota exceeded" } }), {
          status: 403,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.createVolume({
            name: "test-vol",
            size: 50,
            location: "fsn1",
          })),
          Effect.provide(TestLayer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudCreateVolumeError")
      expect(extractFailure(exit).message).toContain("quota exceeded")
    })
  })

  // ── deleteVolume ────────────────────────────────────────────────
  describe("deleteVolume", () => {
    let originalFetch: typeof globalThis.fetch

    beforeEach(() => { originalFetch = globalThis.fetch })
    afterEach(() => { globalThis.fetch = originalFetch })

    const wrapVolumePage = (volumes: Volume[]) => ({
      volumes,
      meta: { pagination: { next_page: null } },
    })

    it("succeeds when volume exists", async () => {
      globalThis.fetch = mock(async (_url: any, init: any) => {
        if (init?.method === "DELETE") {
          return new Response(null, { status: 204 })
        }
        return new Response(JSON.stringify(wrapVolumePage([volume1])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.deleteVolume("ccache-builder-1")),
          Effect.provide(TestLayer)
        )
      )
    })

    it("fails with HcloudVolumeNotFound when volume not found", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapVolumePage([])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.deleteVolume("my-vol")),
          Effect.provide(TestLayer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudVolumeNotFound")
      expect(extractFailure(exit).name).toBe("my-vol")
    })

    it("fails with HcloudDeleteVolumeError when delete API returns error", async () => {
      globalThis.fetch = mock(async (_url: any, init: any) => {
        if (init?.method === "DELETE") {
          return new Response(
            JSON.stringify({ error: { message: "volume is attached" } }),
            { status: 409, headers: { "Content-Type": "application/json" } },
          )
        }
        return new Response(JSON.stringify(wrapVolumePage([volume1])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.deleteVolume("ccache-builder-1")),
          Effect.provide(TestLayer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudDeleteVolumeError")
      expect(extractFailure(exit).message).toContain("volume is attached")
    })
  })

  // ── detachVolume ────────────────────────────────────────────────
  describe("detachVolume", () => {
    let originalFetch: typeof globalThis.fetch

    beforeEach(() => { originalFetch = globalThis.fetch })
    afterEach(() => { globalThis.fetch = originalFetch })

    const wrapVolumePage = (volumes: Volume[]) => ({
      volumes,
      meta: { pagination: { next_page: null } },
    })

    it("succeeds when volume exists and is attached", async () => {
      globalThis.fetch = mock(async (_url: any, init: any) => {
        if (init?.method === "POST") {
          return new Response(JSON.stringify({ action: { id: 1, status: "running" } }), {
            status: 201,
            headers: { "Content-Type": "application/json" },
          })
        }
        return new Response(JSON.stringify(wrapVolumePage([volume1])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      await Effect.runPromise(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.detachVolume("ccache-builder-1")),
          Effect.provide(TestLayer)
        )
      )
    })

    it("fails with HcloudVolumeNotFound when volume not found", async () => {
      globalThis.fetch = mock(async () =>
        new Response(JSON.stringify(wrapVolumePage([])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.detachVolume("my-vol")),
          Effect.provide(TestLayer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudVolumeNotFound")
      expect(extractFailure(exit).name).toBe("my-vol")
    })

    it("fails with HcloudDetachVolumeError when detach API returns error", async () => {
      globalThis.fetch = mock(async (_url: any, init: any) => {
        if (init?.method === "POST") {
          return new Response(
            JSON.stringify({ error: { message: "volume is not attached" } }),
            { status: 409, headers: { "Content-Type": "application/json" } },
          )
        }
        return new Response(JSON.stringify(wrapVolumePage([volume1])), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      }) as any

      const exit = await Effect.runPromiseExit(
        HcloudService.pipe(
          Effect.flatMap(svc => svc.detachVolume("ccache-builder-1")),
          Effect.provide(TestLayer)
        )
      )
      expect(extractFailureTag(exit)).toBe("HcloudDetachVolumeError")
      expect(extractFailure(exit).message).toContain("volume is not attached")
    })
  })
})
