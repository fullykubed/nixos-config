import { describe, it, expect } from "bun:test"
import { Effect, Exit, Fiber, Layer, TestClock, TestContext } from "effect"
import { FileSystem } from "@effect/platform"
import { BunContext } from "@effect/platform-bun"
import { BuildersService, BuildersLive } from "./Builders"
import {
  HcloudService,
  ServerId,
  ImageId,
  VolumeId,
  HcloudServerNotFound,
  HcloudCreateServerError,
  type HcloudServiceShape,
  type Server,
  type Image,
  type Volume,
} from "../Hcloud"
import {
  TailscaleService,
  TailscaleDNSResolutionError,
  HeadscalePreAuthError,
  type TailscaleServiceShape,
} from "../Tailscale"
import { SshService, type SshServiceShape } from "../Ssh"
import { CrocService, CrocRelayUnreachableError, CrocCodeError, CrocRelayPassError, CrocSendError, type CrocServiceShape } from "../Croc"
import { LockService, type LockServiceShape } from "../Lock"

// ── Fixtures ────────────────────────────────────────────────────────

const youngServer: Server = {
  id: ServerId(1),
  name: "builder-1",
  status: "running",
  public_net: { ipv4: { ip: "1.2.3.4" } },
  server_type: { name: "cpx62", description: "CPX 62" },
  created: new Date(Date.now() - 60_000).toISOString(), // 1 min ago
  labels: {},
}

const snapshot: Image = {
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

const ccacheVolume: Volume = {
  id: VolumeId(200),
  name: "ccache-builder-1",
  size: 50,
  location: {
    id: 1, name: "hel1", description: "Helsinki DC Park 1",
    country: "FI", city: "Helsinki", latitude: 60.1695, longitude: 24.9354,
    network_zone: "eu-central",
  },
  labels: { "builder-ccache": "true" },
  linux_device: "/dev/sdb",
  protection: { delete: false },
  server: null,
  created: "2024-01-01T00:00:00Z",
}

// ── Mock helpers ────────────────────────────────────────────────────

/** Base hcloud mock where the server does not exist yet. */
const baseHcloud = (overrides: Partial<HcloudServiceShape> = {}): HcloudServiceShape => ({
  serverExists: () => Effect.succeed(false),
  getServer: (n) => Effect.fail(new HcloudServerNotFound({ name: String(n) })),
  deleteServer: () => Effect.void,
  listServers: () => Effect.succeed([]),
  listImages: () => Effect.succeed([snapshot]),
  getImage: () => Effect.succeed(snapshot),
  imageExists: () => Effect.succeed(true),
  deleteImage: () => Effect.void,
  listVolumes: () => Effect.succeed([ccacheVolume]),
  getVolume: () => Effect.succeed(ccacheVolume),
  volumeExists: () => Effect.succeed(true),
  createServer: () => Effect.succeed(youngServer),
  createVolume: () => Effect.succeed(ccacheVolume),
  deleteVolume: () => Effect.void,
  detachVolume: () => Effect.void,
  ...overrides,
})

const baseTailscale = (overrides: Partial<TailscaleServiceShape> = {}): TailscaleServiceShape => ({
  status: () => Effect.succeed({ BackendState: "Running", TUN: true, Online: true, TailscaleIPs: [], Health: [] }),
  resolveIP: () => Effect.succeed("100.64.0.1"),
  findPeer: () => Effect.succeed("100.64.0.1"),
  mintPreAuthKey: () => Effect.succeed("preauth-key-123"),
  deleteNode: () => Effect.void,
  isReachable: () => Effect.succeed(true),
  ...overrides,
})

const baseCroc = (overrides: Partial<CrocServiceShape> = {}): CrocServiceShape => ({
  relayAddress: "localhost:9009",
  checkRelay: () => Effect.void,
  generateCode: () => Effect.succeed("testcode"),
  readRelayPass: () => Effect.succeed("testpass"),
  send: () => Effect.void,
  ...overrides,
})

const baseSsh: SshServiceShape = {
  exec: () => Effect.succeed({ stdout: "", stderr: "", exitCode: 0 }),
  interactive: () => Effect.succeed(0),
}

const baseLock: LockServiceShape = {
  isLocked: () => Effect.succeed(false),
  acquire: () => Effect.succeed({ waited: false, attempts: 1 }),
  release: () => Effect.void,
  withLock: (_name, f) => f({ waited: false, attempts: 1 }),
}

/** FileSystem mock — stubs the methods used by create/sendSecrets/createInstallScript. */
const MockFileSystem = Layer.succeed(
  FileSystem.FileSystem,
  FileSystem.FileSystem.of({
    exists: () => Effect.succeed(true),
    readFileString: () => Effect.succeed("mock-secret-content"),
    makeTempFileScoped: () => Effect.succeed("/tmp/mock-install-script"),
    writeFileString: () => Effect.void,
  } as any),
)

function buildTestLayer(opts: {
  hcloud?: Partial<HcloudServiceShape>
  tailscale?: Partial<TailscaleServiceShape>
  croc?: Partial<CrocServiceShape>
  ssh?: SshServiceShape
  lock?: LockServiceShape
  fileExists?: boolean
}) {
  return BuildersLive.pipe(
    Layer.provide(Layer.succeed(HcloudService, baseHcloud(opts.hcloud))),
    Layer.provide(Layer.succeed(TailscaleService, baseTailscale(opts.tailscale))),
    Layer.provide(Layer.succeed(SshService, opts.ssh ?? baseSsh)),
    Layer.provide(Layer.succeed(CrocService, baseCroc(opts.croc))),
    Layer.provide(Layer.succeed(LockService, opts.lock ?? baseLock)),
    Layer.provide(opts.fileExists === false ? BunContext.layer : Layer.provideMerge(MockFileSystem, BunContext.layer)),
  )
}

function extractFailure(exit: Exit.Exit<any, any>): any {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return cause.error
  return undefined
}

// ── Tests ───────────────────────────────────────────────────────────

describe("BuildersService", () => {
  describe("create", () => {
    // ── Happy path ─────────────────────────────────────────────

    it("succeeds when all stages complete", async () => {
      let serverExistsCount = 0
      const layer = buildTestLayer({
        hcloud: {
          // 1st call (pre-creation check): false → proceed to create
          // Subsequent (isReady polling): true → server exists
          serverExists: () => { serverExistsCount++; return Effect.succeed(serverExistsCount > 1) },
        },
        tailscale: {
          // isReady: resolve succeeds, isReachable succeeds
          resolveIP: () => Effect.succeed("100.64.0.1"),
          isReachable: () => Effect.succeed(true),
        },
      })

      const program = Effect.gen(function* () {
        const fiber = yield* BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.fork,
        )
        // Advance past readiness polling
        yield* TestClock.adjust("5 seconds")
        return yield* Fiber.join(fiber)
      }).pipe(
        Effect.provide(layer),
        Effect.provide(TestContext.TestContext),
      )

      await Effect.runPromise(program)
    })

    it("short-circuits when server already exists and is ready", async () => {
      let createServerCalled = false

      const layer = buildTestLayer({
        hcloud: {
          serverExists: () => Effect.succeed(true),
          getServer: () => Effect.succeed(youngServer),
          createServer: () => { createServerCalled = true; return Effect.succeed(youngServer) },
        },
        tailscale: {
          resolveIP: () => Effect.succeed("100.64.0.1"),
          isReachable: () => Effect.succeed(true),
        },
      })

      await Effect.runPromise(
        BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.provide(layer),
        )
      )
      expect(createServerCalled).toBe(false)
    })

    // ── Pre-creation failures (no cleanup needed) ──────────────

    it("fails with BuilderCreateError when no snapshot found", async () => {
      const layer = buildTestLayer({
        hcloud: { listImages: () => Effect.succeed([]) },
      })

      const exit = await Effect.runPromiseExit(
        BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.provide(layer),
        )
      )
      const err = extractFailure(exit)
      expect(err._tag).toBe("BuilderCreateError")
      expect(err.message).toContain("No snapshot found")
    })

    it("fails with BuilderCreateError when secret file is missing", async () => {
      const layer = buildTestLayer({ fileExists: false })

      // BunContext.layer provides a real FileSystem — secret paths won't exist
      // in the test environment, so fs.exists will return false.
      const exit = await Effect.runPromiseExit(
        BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.provide(layer),
        )
      )
      const err = extractFailure(exit)
      expect(err._tag).toBe("BuilderCreateError")
      expect(err.message).toContain("Secret file not found")
    })

    it("fails with BuilderCreateError when croc relay is unreachable", async () => {
      const layer = buildTestLayer({
        croc: {
          checkRelay: () => Effect.fail(new CrocRelayUnreachableError({ relayAddress: "localhost:9009" })),
        },
      })

      const exit = await Effect.runPromiseExit(
        BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.provide(layer),
        )
      )
      const err = extractFailure(exit)
      expect(err._tag).toBe("BuilderCreateError")
      expect(err.message).toContain("Croc relay not reachable")
    })

    it("fails with BuilderCreateError when headscale pre-auth key minting fails", async () => {
      const layer = buildTestLayer({
        tailscale: {
          mintPreAuthKey: () => Effect.fail(new HeadscalePreAuthError({ message: "API key expired" })),
          // isReady needs these to return false (server doesn't exist)
          resolveIP: (h) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "" })),
          isReachable: () => Effect.succeed(false),
        },
      })

      const exit = await Effect.runPromiseExit(
        BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.provide(layer),
        )
      )
      const err = extractFailure(exit)
      expect(err._tag).toBe("BuilderCreateError")
      expect(err.message).toContain("pre-auth key")
    })

    it("fails with BuilderCreateError when croc code generation fails", async () => {
      const layer = buildTestLayer({
        croc: {
          generateCode: () => Effect.fail(new CrocCodeError({ message: "entropy exhausted" })),
        },
        tailscale: {
          resolveIP: (h) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "" })),
          isReachable: () => Effect.succeed(false),
        },
      })

      const exit = await Effect.runPromiseExit(
        BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.provide(layer),
        )
      )
      const err = extractFailure(exit)
      expect(err._tag).toBe("BuilderCreateError")
      expect(err.message).toContain("croc code")
    })

    it("fails with BuilderCreateError when croc relay pass read fails", async () => {
      const layer = buildTestLayer({
        croc: {
          readRelayPass: () => Effect.fail(new CrocRelayPassError({ path: "/tmp/relay-pass", message: "file not found" })),
        },
        tailscale: {
          resolveIP: (h) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "" })),
          isReachable: () => Effect.succeed(false),
        },
      })

      const exit = await Effect.runPromiseExit(
        BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.provide(layer),
        )
      )
      const err = extractFailure(exit)
      expect(err._tag).toBe("BuilderCreateError")
      expect(err.message).toContain("relay password")
    })

    it("fails with BuilderCreateError when ccache volume creation fails", async () => {
      const layer = buildTestLayer({
        hcloud: {
          // No existing volume → triggers createVolume
          listVolumes: () => Effect.succeed([]),
          createVolume: () => Effect.fail(new HcloudCreateServerError({ name: "ccache-builder-1", message: "quota exceeded" }) as any),
        },
        tailscale: {
          resolveIP: (h) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "" })),
          isReachable: () => Effect.succeed(false),
        },
      })

      const exit = await Effect.runPromiseExit(
        BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.provide(layer),
        )
      )
      const err = extractFailure(exit)
      expect(err._tag).toBe("BuilderCreateError")
      expect(err.message).toContain("ccache volume")
    })

    // ── Post-creation failures (cleanup should destroy server) ─

    it("destroys server when createServer fails inside cleanup wrapper", async () => {
      let deleteServerCalled = false

      const layer = buildTestLayer({
        hcloud: {
          createServer: () => Effect.fail(new HcloudCreateServerError({ name: "builder-1", message: "server limit exceeded" })),
          deleteServer: () => { deleteServerCalled = true; return Effect.void },
        },
        tailscale: {
          resolveIP: (h) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "" })),
          isReachable: () => Effect.succeed(false),
        },
      })

      const exit = await Effect.runPromiseExit(
        BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.provide(layer),
        )
      )
      expect(extractFailure(exit)._tag).toBe("BuilderCreateError")
      expect(deleteServerCalled).toBe(true)
    })

    it("destroys server when secret delivery (croc send) fails", async () => {
      let deleteServerCalled = false

      const layer = buildTestLayer({
        hcloud: {
          deleteServer: () => { deleteServerCalled = true; return Effect.void },
        },
        croc: {
          send: () => Effect.fail(new CrocSendError({ target: "builder-1", attempts: 12, message: "all retries exhausted" })),
        },
        tailscale: {
          resolveIP: (h) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "" })),
          isReachable: () => Effect.succeed(false),
        },
      })

      const exit = await Effect.runPromiseExit(
        BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.provide(layer),
        )
      )
      expect(extractFailure(exit)._tag).toBe("BuilderCreateError")
      expect(deleteServerCalled).toBe(true)
    })

    it("destroys server when builder never becomes ready (poll timeout)", async () => {
      let deleteServerCalled = false
      let serverExistsCount = 0

      const layer = buildTestLayer({
        hcloud: {
          // 1st call (pre-creation check): false → skip to creation
          // Subsequent calls (isReady polling): true → server exists but not reachable
          serverExists: () => { serverExistsCount++; return Effect.succeed(serverExistsCount > 1) },
          deleteServer: () => { deleteServerCalled = true; return Effect.void },
        },
        tailscale: {
          // Post-creation: server exists now, but never becomes reachable
          resolveIP: (h) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "not found" })),
          isReachable: () => Effect.succeed(false),
        },
      })

      const program = Effect.gen(function* () {
        const fiber = yield* BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.fork,
        )

        // Advance past the 180s readiness timeout
        yield* TestClock.adjust("185 seconds")

        return yield* Fiber.await(fiber)
      }).pipe(
        Effect.provide(layer),
        Effect.provide(TestContext.TestContext),
      )

      const exit = await Effect.runPromise(program)
      expect(Exit.isFailure(exit)).toBe(true)
      expect(extractFailure(exit)._tag).toBe("BuilderCreateError")
      expect(extractFailure(exit).message).toContain("did not become reachable")
      expect(deleteServerCalled).toBe(true)
    })

    // ── Server disappears externally during ensureReadyOrDestroy ─

    it("skips destroy when server disappears during readiness poll", async () => {
      let deleteServerCalled = false
      let serverExistsCallCount = 0
      let resolveIPCount = 0

      const layer = buildTestLayer({
        hcloud: {
          serverExists: () => {
            serverExistsCallCount++
            // 1: pre-creation check → true (enters ensureReadyOrDestroy)
            // 2: isReady in ensureReadyOrDestroy → true (server exists, not reachable)
            // 3: poll iteration in ensureReadyOrDestroy → false (gone → short-circuit)
            // 4+: post-creation isReady poll → true (newly created server)
            if (serverExistsCallCount === 3) return Effect.succeed(false)
            return Effect.succeed(true)
          },
          getServer: () => Effect.succeed(youngServer),
          deleteServer: () => { deleteServerCalled = true; return Effect.void },
        },
        tailscale: {
          resolveIP: () => {
            resolveIPCount++
            // 1: during ensureReadyOrDestroy initial isReady → fail (not reachable)
            // 2+: post-creation → succeed
            if (resolveIPCount <= 1) return Effect.fail(new TailscaleDNSResolutionError({ hostname: "builder-1", error: "not found" }))
            return Effect.succeed("100.64.0.1")
          },
          isReachable: (() => {
            let count = 0
            return () => { count++; return Effect.succeed(count > 1) }
          })(),
        },
      })

      const program = Effect.gen(function* () {
        const fiber = yield* BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.fork,
        )
        yield* TestClock.adjust("10 seconds")
        return yield* Fiber.join(fiber)
      }).pipe(
        Effect.provide(layer),
        Effect.provide(TestContext.TestContext),
      )

      await Effect.runPromise(program)
      // ensureReadyOrDestroy should NOT have called destroy — server disappeared on its own
      expect(deleteServerCalled).toBe(false)
    })

    it("skips destroy when server is gone at initial isReady check", async () => {
      let deleteServerCalled = false
      let _serverExistsCount = 0

      const layer = buildTestLayer({
        hcloud: {
          serverExists: () => {
            _serverExistsCount++
            // 1: pre-creation check → true (enters ensureReadyOrDestroy)
            // 2: isReady in ensureReadyOrDestroy → false (gone → short-circuit immediately)
            // 3+: post-creation isReady → true (newly created server)
            if (_serverExistsCount === 2) return Effect.succeed(false)
            return Effect.succeed(true)
          },
          getServer: () => Effect.succeed(youngServer),
          deleteServer: () => { deleteServerCalled = true; return Effect.void },
        },
        tailscale: {
          resolveIP: () => {
            // Post-creation calls succeed
            return Effect.succeed("100.64.0.1")
          },
          isReachable: () => Effect.succeed(true),
        },
      })

      const program = Effect.gen(function* () {
        const fiber = yield* BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.fork,
        )
        yield* TestClock.adjust("10 seconds")
        return yield* Fiber.join(fiber)
      }).pipe(
        Effect.provide(layer),
        Effect.provide(TestContext.TestContext),
      )

      await Effect.runPromise(program)
      expect(deleteServerCalled).toBe(false)
    })

    // ── Stale builder: old, not ready → destroyed then recreated ─

    it("destroys stale builder and continues creation", async () => {
      let deleteServerCalled = false
      let createServerCalled = false
      let _serverExistsCount = 0
      const staleServer: Server = {
        ...youngServer,
        created: new Date(Date.now() - 60 * 60_000).toISOString(), // 60 min ago
      }

      const layer = buildTestLayer({
        hcloud: {
          serverExists: () => {
            _serverExistsCount++
            // 1: pre-creation check → true (enters ensureReadyOrDestroy)
            // 2: isReady in ensureReadyOrDestroy → true (server exists, stale, not reachable → destroy)
            // 3+: post-creation isReady → true (newly created server)
            return Effect.succeed(true)
          },
          getServer: () => Effect.succeed(staleServer),
          deleteServer: () => {
            deleteServerCalled = true
            return Effect.void
          },
          createServer: () => { createServerCalled = true; return Effect.succeed(youngServer) },
        },
        tailscale: {
          // Not reachable during ensureReadyOrDestroy, reachable after recreation
          resolveIP: (() => {
            let count = 0
            return (h: string) => {
              count++
              // 1: ensureReadyOrDestroy isReady → fail (not reachable)
              // 2+: post-creation → succeed
              if (count <= 1) return Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "" }))
              return Effect.succeed("100.64.0.1")
            }
          })(),
          isReachable: (() => {
            let count = 0
            return () => { count++; return Effect.succeed(count > 1) }
          })(),
        },
      })

      const program = Effect.gen(function* () {
        const fiber = yield* BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.fork,
        )
        // Advance past readiness polling
        yield* TestClock.adjust("10 seconds")
        return yield* Fiber.join(fiber)
      }).pipe(
        Effect.provide(layer),
        Effect.provide(TestContext.TestContext),
      )

      await Effect.runPromise(program)
      expect(deleteServerCalled).toBe(true)
      expect(createServerCalled).toBe(true)
    })

    // ── Lock contention: another process created the builder ────

    it("returns early when another process created the builder during lock wait", async () => {
      let createServerCalled = false

      const layer = buildTestLayer({
        hcloud: {
          // Server doesn't exist initially, but exists after lock wait
          serverExists: (() => {
            let count = 0
            return () => { count++; return Effect.succeed(count > 1) }
          })(),
          getServer: () => Effect.succeed(youngServer),
          createServer: () => { createServerCalled = true; return Effect.succeed(youngServer) },
        },
        tailscale: {
          resolveIP: () => Effect.succeed("100.64.0.1"),
          isReachable: () => Effect.succeed(true),
        },
        lock: {
          isLocked: () => Effect.succeed(false),
          acquire: () => Effect.succeed({ waited: true, attempts: 3 }),
          release: () => Effect.void,
          withLock: (_name, f) => f({ waited: true, attempts: 3 }),
        },
      })

      await Effect.runPromise(
        BuildersService.pipe(
          Effect.flatMap(svc => svc.create("builder-1")),
          Effect.provide(layer),
        )
      )
      expect(createServerCalled).toBe(false)
    })
  })
})
