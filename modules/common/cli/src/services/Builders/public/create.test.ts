import { describe, it, expect } from "bun:test"
import { Effect, Exit, Fiber, TestClock, TestContext } from "effect"
import { SilentLogger } from "../../../lib/test/logger"
import { FileSystem } from "@effect/platform"
import { HcloudCreateServerError, type HcloudServiceShape } from "../../Hcloud"
import {
  TailscaleDNSResolutionError,
  HeadscalePreAuthError,
  type TailscaleServiceShape,
} from "../../Tailscale"
import {
  CrocRelayUnreachableError,
  CrocCodeError,
  CrocRelayPassError,
  CrocSendError,
  type CrocServiceShape,
} from "../../Croc"
import { create } from "./create"
import type { LockServiceShape } from "../../Lock"
import {
  youngServer,
  baseLock,
  makeTestContext,
} from "../helpers.test"

// ── Helpers ──────────────────────────────────────────────────────────

function extractFailure(exit: Exit.Exit<any, any>): any {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return cause.error
  return undefined
}

const run = (opts: {
  hcloud?: Partial<HcloudServiceShape>
  tailscale?: Partial<TailscaleServiceShape>
  croc?: Partial<CrocServiceShape>
  lock?: LockServiceShape
  fs?: FileSystem.FileSystem
}) => create("builder-1").pipe(Effect.provide(makeTestContext(opts)), Effect.provide(SilentLogger))

// ── Tests ────────────────────────────────────────────────────────────

describe("create", () => {
  // ── Happy path ────────────────────────────────────────────────

  it("succeeds when all stages complete", async () => {
    let serverExistsCount = 0
    const program = Effect.gen(function* () {
      const fiber = yield* Effect.fork(run({
        hcloud: { serverExists: () => { serverExistsCount++; return Effect.succeed(serverExistsCount > 1) } },
        tailscale: { resolveIP: () => Effect.succeed("100.64.0.1"), isReachable: () => Effect.succeed(true) },
      }))
      yield* TestClock.adjust("5 seconds")
      return yield* Fiber.join(fiber)
    }).pipe(Effect.provide(TestContext.TestContext))

    await Effect.runPromise(program)
  })

  it("short-circuits when server already exists and is ready", async () => {
    let createServerCalled = false
    await Effect.runPromise(run({
      hcloud: {
        serverExists: () => Effect.succeed(true),
        getServer: () => Effect.succeed(youngServer),
        createServer: () => { createServerCalled = true; return Effect.succeed(youngServer) },
      },
      tailscale: { resolveIP: () => Effect.succeed("100.64.0.1"), isReachable: () => Effect.succeed(true) },
    }))
    expect(createServerCalled).toBe(false)
  })

  // ── Pre-creation failures ─────────────────────────────────────

  it("fails with BuilderCreateError when no snapshot found", async () => {
    const exit = await Effect.runPromiseExit(run({ hcloud: { listImages: () => Effect.succeed([]) } }))
    const err = extractFailure(exit)
    expect(err._tag).toBe("BuilderCreateError")
    expect(err.message).toContain("No snapshot found")
  })

  it("fails with BuilderCreateError when secret file is missing", async () => {
    const exit = await Effect.runPromiseExit(run({
      fs: FileSystem.FileSystem.of({ exists: () => Effect.succeed(false) } as any),
    }))
    const err = extractFailure(exit)
    expect(err._tag).toBe("BuilderCreateError")
    expect(err.message).toContain("Secret file not found")
  })

  it("fails with BuilderCreateError when croc relay is unreachable", async () => {
    const exit = await Effect.runPromiseExit(run({
      croc: { checkRelay: () => Effect.fail(new CrocRelayUnreachableError({ relayAddress: "localhost:9009" })) },
    }))
    const err = extractFailure(exit)
    expect(err._tag).toBe("BuilderCreateError")
    expect(err.message).toContain("Croc relay not reachable")
  })

  it("fails with BuilderCreateError when headscale pre-auth key minting fails", async () => {
    const exit = await Effect.runPromiseExit(run({
      tailscale: {
        mintPreAuthKey: () => Effect.fail(new HeadscalePreAuthError({ message: "API key expired" })),
        resolveIP: (h: string) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "" })),
      },
    }))
    const err = extractFailure(exit)
    expect(err._tag).toBe("BuilderCreateError")
    expect(err.message).toContain("pre-auth key")
  })

  it("fails with BuilderCreateError when croc code generation fails", async () => {
    const exit = await Effect.runPromiseExit(run({
      croc: { generateCode: () => Effect.fail(new CrocCodeError({ message: "entropy exhausted" })) },
      tailscale: { resolveIP: (h: string) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "" })) },
    }))
    const err = extractFailure(exit)
    expect(err._tag).toBe("BuilderCreateError")
    expect(err.message).toContain("croc code")
  })

  it("fails with BuilderCreateError when croc relay pass read fails", async () => {
    const exit = await Effect.runPromiseExit(run({
      croc: { readRelayPass: () => Effect.fail(new CrocRelayPassError({ path: "/tmp/relay-pass", message: "file not found" })) },
      tailscale: { resolveIP: (h: string) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "" })) },
    }))
    const err = extractFailure(exit)
    expect(err._tag).toBe("BuilderCreateError")
    expect(err.message).toContain("relay password")
  })

  it("fails with BuilderCreateError when ccache volume creation fails", async () => {
    const exit = await Effect.runPromiseExit(run({
      hcloud: {
        listVolumes: () => Effect.succeed([]),
        createVolume: () => Effect.fail(new HcloudCreateServerError({ name: "ccache-builder-1", message: "quota exceeded" }) as any),
      },
      tailscale: { resolveIP: (h: string) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "" })) },
    }))
    const err = extractFailure(exit)
    expect(err._tag).toBe("BuilderCreateError")
    expect(err.message).toContain("ccache volume")
  })

  // ── Post-creation failures (cleanup should destroy server) ────

  it("destroys server when createServer fails inside cleanup wrapper", async () => {
    let deleteServerCalled = false
    const exit = await Effect.runPromiseExit(run({
      hcloud: {
        createServer: () => Effect.fail(new HcloudCreateServerError({ name: "builder-1", message: "server limit exceeded" })),
        deleteServer: () => { deleteServerCalled = true; return Effect.void },
      },
      tailscale: { resolveIP: (h: string) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "" })) },
    }))
    expect(extractFailure(exit)._tag).toBe("BuilderCreateError")
    expect(deleteServerCalled).toBe(true)
  })

  it("destroys server when secret delivery (croc send) fails", async () => {
    let deleteServerCalled = false
    const exit = await Effect.runPromiseExit(run({
      hcloud: { deleteServer: () => { deleteServerCalled = true; return Effect.void } },
      croc: { send: () => Effect.fail(new CrocSendError({ target: "builder-1", attempts: 12, message: "all retries exhausted" })) },
      tailscale: { resolveIP: (h: string) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "" })) },
    }))
    expect(extractFailure(exit)._tag).toBe("BuilderCreateError")
    expect(deleteServerCalled).toBe(true)
  })

  it("destroys server when builder never becomes ready (poll timeout)", async () => {
    let deleteServerCalled = false
    let serverExistsCount = 0
    const program = Effect.gen(function* () {
      const fiber = yield* Effect.fork(run({
        hcloud: {
          serverExists: () => { serverExistsCount++; return Effect.succeed(serverExistsCount > 1) },
          deleteServer: () => { deleteServerCalled = true; return Effect.void },
        },
        tailscale: { resolveIP: (h: string) => Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "not found" })) },
      }))
      yield* TestClock.adjust("185 seconds")
      return yield* Fiber.await(fiber)
    }).pipe(Effect.provide(TestContext.TestContext))

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

    const program = Effect.gen(function* () {
      const fiber = yield* Effect.fork(run({
        hcloud: {
          serverExists: () => {
            serverExistsCallCount++
            if (serverExistsCallCount === 3) return Effect.succeed(false)
            return Effect.succeed(true)
          },
          getServer: () => Effect.succeed(youngServer),
          deleteServer: () => { deleteServerCalled = true; return Effect.void },
        },
        tailscale: {
          resolveIP: () => {
            resolveIPCount++
            if (resolveIPCount <= 1) return Effect.fail(new TailscaleDNSResolutionError({ hostname: "builder-1", error: "not found" }))
            return Effect.succeed("100.64.0.1")
          },
          isReachable: (() => { let c = 0; return () => { c++; return Effect.succeed(c > 1) } })(),
        },
      }))
      yield* TestClock.adjust("10 seconds")
      return yield* Fiber.join(fiber)
    }).pipe(Effect.provide(TestContext.TestContext))

    await Effect.runPromise(program)
    expect(deleteServerCalled).toBe(false)
  })

  it("skips destroy when server is gone at initial isReady check", async () => {
    let deleteServerCalled = false
    let serverExistsCount = 0

    const program = Effect.gen(function* () {
      const fiber = yield* Effect.fork(run({
        hcloud: {
          serverExists: () => {
            serverExistsCount++
            if (serverExistsCount === 2) return Effect.succeed(false)
            return Effect.succeed(true)
          },
          getServer: () => Effect.succeed(youngServer),
          deleteServer: () => { deleteServerCalled = true; return Effect.void },
        },
        tailscale: { resolveIP: () => Effect.succeed("100.64.0.1"), isReachable: () => Effect.succeed(true) },
      }))
      yield* TestClock.adjust("10 seconds")
      return yield* Fiber.join(fiber)
    }).pipe(Effect.provide(TestContext.TestContext))

    await Effect.runPromise(program)
    expect(deleteServerCalled).toBe(false)
  })

  // ── Stale builder ────────────────────────────────────────────

  it("destroys stale builder and continues creation", async () => {
    let deleteServerCalled = false
    let createServerCalled = false
    const staleServer = { ...youngServer, created: new Date(Date.now() - 60 * 60_000).toISOString() }

    const program = Effect.gen(function* () {
      const fiber = yield* Effect.fork(run({
        hcloud: {
          serverExists: () => Effect.succeed(true),
          getServer: () => Effect.succeed(staleServer),
          deleteServer: () => { deleteServerCalled = true; return Effect.void },
          createServer: () => { createServerCalled = true; return Effect.succeed(youngServer) },
        },
        tailscale: {
          resolveIP: (() => { let c = 0; return (h: string) => { c++; return c <= 1 ? Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "" })) : Effect.succeed("100.64.0.1") } })(),
          isReachable: (() => { let c = 0; return () => { c++; return Effect.succeed(c > 1) } })(),
        },
      }))
      yield* TestClock.adjust("10 seconds")
      return yield* Fiber.join(fiber)
    }).pipe(Effect.provide(TestContext.TestContext))

    await Effect.runPromise(program)
    expect(deleteServerCalled).toBe(true)
    expect(createServerCalled).toBe(true)
  })

  // ── Lock contention ──────────────────────────────────────────

  it("returns early when another process created the builder during lock wait", async () => {
    let createServerCalled = false
    let serverExistsCount = 0
    await Effect.runPromise(run({
      hcloud: {
        serverExists: () => { serverExistsCount++; return Effect.succeed(serverExistsCount > 1) },
        getServer: () => Effect.succeed(youngServer),
        createServer: () => { createServerCalled = true; return Effect.succeed(youngServer) },
      },
      tailscale: { resolveIP: () => Effect.succeed("100.64.0.1"), isReachable: () => Effect.succeed(true) },
      lock: { ...baseLock, withLock: (_name: string, f: any) => f({ waited: true, attempts: 3 }) },
    }))
    expect(createServerCalled).toBe(false)
  })
})
