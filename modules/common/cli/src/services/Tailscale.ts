import { Context, Data, Effect, Layer } from "effect"
import { FileSystem } from "@effect/platform"
import { ShellService, ShellError, JsonParseError } from "./Shell"

const HEADSCALE_API_URL = "https://headscale.panfactumcf.com/api/v1"
const HEADSCALE_API_KEY_PATH = "/run/agenix/headscale-api-key"
const HEADSCALE_USER_ID = "1"

/**
 * Tailscale VPN service for builder hostname resolution and connectivity checks.
 *
 * Builders join the Tailscale/Headscale network during provisioning and are
 * addressed by their MagicDNS hostname (e.g. "builder-1") rather than
 * ephemeral public IPs.  This service wraps the `tailscale` CLI to:
 *
 *   status     – fetch the local node's Tailscale status (backend state, IPs, peers)
 *   resolveIP  – resolve a builder hostname to its Tailscale IPv4 address
 *   isReachable – quick TCP connectivity check (nc -z) to a host:port
 *
 * resolveIP is the primary method used throughout the codebase — commands
 * call it to get a builder's stable VPN address before SSH-ing into it.
 */

/** A single peer from the `tailscale status --json` Peer map. */
export interface TailscalePeer {
  HostName: string
  TailscaleIPs: string[]
  Online: boolean
}

/** Subset of `tailscale status --json` output relevant to this service. */
export interface TailscaleStatus {
  BackendState: string
  TUN: boolean
  Online: boolean
  TailscaleIPs: string[]
  Health: string[]
  Peer?: Record<string, TailscalePeer>
}

/** The local Tailscale daemon is not in the "Running" state. */
export class TailscaleNotConnectedError extends Data.TaggedError("TailscaleNotConnectedError")<{
  readonly backendState: string
  readonly message: string
}> {}

/** `tailscale ip -4 <hostname>` failed — the builder isn't registered or DNS hasn't propagated. */
export class TailscaleDNSResolutionError extends Data.TaggedError("TailscaleDNSResolutionError")<{
  readonly hostname: string
  readonly error: string
}> {}

/** A Tailscale operation exceeded its deadline.  (Currently unused but reserved.) */
export class TailscaleTimeoutError extends Data.TaggedError("TailscaleTimeoutError")<{
  readonly operation: string
  readonly timeout: number
}> {}

/** Failed to mint a Headscale pre-auth key. */
export class HeadscalePreAuthError extends Data.TaggedError("HeadscalePreAuthError")<{
  readonly message: string
}> {}

/** Failed to delete a Headscale node. */
export class HeadscaleNodeError extends Data.TaggedError("HeadscaleNodeError")<{
  readonly hostname: string
  readonly message: string
}> {}

/** Union of all Tailscale-specific error types. */
export type TailscaleError =
  | TailscaleNotConnectedError
  | TailscaleDNSResolutionError
  | TailscaleTimeoutError
  | HeadscalePreAuthError
  | HeadscaleNodeError

export interface TailscaleServiceShape {
  /**
   * Get the local Tailscale node's status.
   * Fails with TailscaleNotConnectedError if BackendState != "Running".
   */
  status(): Effect.Effect<TailscaleStatus, ShellError | JsonParseError | TailscaleNotConnectedError>

  /**
   * Resolve a Tailscale hostname to its IPv4 address via `tailscale ip -4`.
   * Validates the returned string is a dotted-quad before returning.
   */
  resolveIP(hostname: string): Effect.Effect<string, ShellError | TailscaleDNSResolutionError>

  /**
   * Find a peer by hostname in the Tailscale status JSON and return its first IP.
   * Unlike resolveIP (which uses `tailscale ip -4` and requires full registration),
   * findPeer works as soon as the peer appears in the status — useful for polling
   * newly-created builders.
   */
  findPeer(hostname: string): Effect.Effect<string, ShellError | JsonParseError | TailscaleDNSResolutionError>

  /**
   * Mint an ephemeral Headscale pre-auth key via the Headscale REST API.
   * Reads the API key from the agenix secret file on disk.
   */
  mintPreAuthKey(): Effect.Effect<string, HeadscalePreAuthError>

  /**
   * Delete a Headscale node by hostname.
   * Lists all nodes, finds the one matching by givenName or name, and deletes it.
   * Logs warnings and returns without error if the API key is missing or the node
   * is not found (idempotent cleanup).
   */
  deleteNode(hostname: string): Effect.Effect<void, HeadscaleNodeError>

  /**
   * TCP connectivity check using `nc -z -w 3`.
   * Returns true if the port is open, false otherwise.  Never fails.
   */
  isReachable(hostname: string, port: number): Effect.Effect<boolean>
}

export class TailscaleService extends Context.Tag("TailscaleService")<
  TailscaleService,
  TailscaleServiceShape
>() {}

const readHeadscaleApiKey = (fs: FileSystem.FileSystem) =>
  fs.readFileString(HEADSCALE_API_KEY_PATH).pipe(
    Effect.map(text => text.trim()),
    Effect.catchAll(() => Effect.fail(new HeadscalePreAuthError({
      message: `Failed to read headscale API key from ${HEADSCALE_API_KEY_PATH}`
    })))
  )

const makeTailscaleService = (shell: ShellService["Type"], fs: FileSystem.FileSystem): TailscaleServiceShape => ({
  status: () => Effect.gen(function* () {
    const statusResult = yield* shell.execJson<TailscaleStatus>("tailscale", ["status", "--json"])

    if (statusResult.BackendState !== "Running") {
      yield* Effect.fail(new TailscaleNotConnectedError({
        backendState: statusResult.BackendState,
        message: `Tailscale is not running (state: ${statusResult.BackendState})`
      }))
    }

    return statusResult
  }),

  resolveIP: (hostname: string) => Effect.gen(function* () {
    const result = yield* shell.exec("tailscale", ["ip", "-4", hostname]).pipe(
      Effect.catchAll((error) => Effect.fail(new TailscaleDNSResolutionError({
        hostname,
        error: error.stderr || String(error)
      })))
    )

    const ip = result.stdout.trim()

    if (!ip || !/^\d+\.\d+\.\d+\.\d+$/.test(ip)) {
      return yield* Effect.fail(new TailscaleDNSResolutionError({
        hostname,
        error: `Invalid IP address returned: ${ip}`
      }))
    }

    return ip
  }),

  findPeer: (hostname: string) => Effect.gen(function* () {
    const status = yield* shell.execJson<TailscaleStatus>("tailscale", ["status", "--json"])
    const peer = Object.values(status.Peer ?? {}).find(p => p.HostName === hostname)
    const ip = peer?.TailscaleIPs[0]

    if (!ip) {
      return yield* Effect.fail(new TailscaleDNSResolutionError({
        hostname,
        error: "Peer not found in tailscale status"
      }))
    }

    return ip
  }),

  mintPreAuthKey: () => Effect.gen(function* () {
    const apiKey = yield* readHeadscaleApiKey(fs)

    const expiry = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString()

    const response = yield* Effect.tryPromise({
      try: () => fetch(`${HEADSCALE_API_URL}/preauthkey`, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          user: HEADSCALE_USER_ID,
          reusable: false,
          ephemeral: true,
          expiration: expiry,
        }),
      }),
      catch: () => new HeadscalePreAuthError({
        message: "Failed to reach headscale API"
      })
    })

    if (!response.ok) {
      return yield* Effect.fail(new HeadscalePreAuthError({
        message: `Headscale API returned ${response.status}: ${response.statusText}`
      }))
    }

    const parsed = yield* Effect.tryPromise({
      try: () => response.json() as Promise<{ preAuthKey?: { key?: string } }>,
      catch: () => new HeadscalePreAuthError({
        message: "Failed to parse headscale pre-auth key response"
      })
    })

    const key = parsed.preAuthKey?.key
    if (!key) {
      return yield* Effect.fail(new HeadscalePreAuthError({
        message: "Headscale response did not contain a pre-auth key"
      }))
    }

    return key
  }),

  deleteNode: (hostname: string) => Effect.gen(function* () {
    const apiKey = yield* readHeadscaleApiKey(fs).pipe(
      Effect.catchAll(() =>
        Effect.logWarning("Headscale API key not found, skipping node cleanup").pipe(
          Effect.map(() => "")
        )
      )
    )

    if (!apiKey) return

    const headers = { "Authorization": `Bearer ${apiKey}` }

    // List nodes
    const listResponse = yield* Effect.tryPromise({
      try: () => fetch(`${HEADSCALE_API_URL}/node`, { headers }),
      catch: () => new HeadscaleNodeError({ hostname, message: "Failed to reach headscale API" })
    })

    if (!listResponse.ok) {
      yield* Effect.logWarning(`Failed to list headscale nodes (${listResponse.status}), skipping node cleanup`)
      return
    }

    const nodesData = yield* Effect.tryPromise({
      try: () => listResponse.json() as Promise<{ nodes: { id: string; givenName?: string; name?: string }[] }>,
      catch: () => new HeadscaleNodeError({ hostname, message: "Failed to parse headscale nodes response" })
    }).pipe(
      Effect.catchAll(() => Effect.succeed({ nodes: [] as { id: string; givenName?: string; name?: string }[] }))
    )

    const node = nodesData.nodes.find(n =>
      n.givenName === hostname || n.name === hostname
    )

    if (!node) {
      yield* Effect.logWarning(`No headscale node found for ${hostname} (may already be cleaned up)`)
      return
    }

    // Delete the node
    const deleteResponse = yield* Effect.tryPromise({
      try: () => fetch(`${HEADSCALE_API_URL}/node/${node.id}`, { method: "DELETE", headers }),
      catch: () => new HeadscaleNodeError({ hostname, message: `Failed to delete headscale node ${node.id}` })
    })

    if (deleteResponse.ok) {
      yield* Effect.log(`Removed ${hostname} from headscale (node ${node.id})`)
    } else {
      yield* Effect.logWarning(`Failed to delete headscale node ${node.id} for ${hostname}`)
    }
  }),

  isReachable: (hostname: string, port: number) =>
    shell.exec("nc", ["-z", "-w", "3", hostname, port.toString()]).pipe(
      Effect.map(() => true),
      Effect.catchAll(() => Effect.succeed(false))
    )
})

export const TailscaleLive = Layer.effect(
  TailscaleService,
  Effect.gen(function* () {
    const shell = yield* ShellService
    const fileSystem = yield* FileSystem.FileSystem
    return makeTailscaleService(shell, fileSystem)
  })
)
