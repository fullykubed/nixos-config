import { Brand, Context, Data, Effect, Layer, Schedule } from "effect"
import { FileSystem } from "@effect/platform"

/**
 * Hetzner Cloud API service.
 *
 * Manages the ephemeral builder VM fleet via the Hetzner Cloud REST API:
 *
 *   Servers  – list / get / create / delete builder VMs
 *   Images   – list / delete snapshots (builder disk images)
 *   Volumes  – list / create / delete / detach ccache volumes
 *
 * Authentication: reads the API token from /run/agenix/hetzner-api-token
 * (decrypted at boot by agenix) with a fallback to HCLOUD_TOKEN env var.
 * The token is cached in-process after first read.
 *
 * Depends on: FileSystem (injected via Layer).
 */

// ── Domain types ────────────────────────────────────────────────────────

export type ServerId = number & Brand.Brand<"ServerId">
export const ServerId = Brand.nominal<ServerId>()

export type ImageId = number & Brand.Brand<"ImageId">
export const ImageId = Brand.nominal<ImageId>()

export type VolumeId = number & Brand.Brand<"VolumeId">
export const VolumeId = Brand.nominal<VolumeId>()

/** A Hetzner Cloud server (VM). Mirrors the JSON shape from `hcloud server list -o json`. */
export interface Server {
  readonly id: ServerId
  readonly name: string
  readonly status: "running" | "starting" | "stopping" | "off" | "deleting" | "migrating" | "rebuilding" | "unknown"
  readonly public_net: { readonly ipv4: { readonly ip: string } }
  readonly server_type: { readonly name: string; readonly description: string }
  readonly created: string
  readonly labels: Record<string, string>
}

/** A Hetzner Cloud image (snapshot, system, backup, or app). */
export interface Image {
  readonly id: ImageId
  readonly name: string | null
  readonly description: string | null
  readonly type: "system" | "snapshot" | "backup" | "app"
  readonly status: "available" | "creating"
  readonly architecture: "x86" | "arm"
  readonly os_flavor: string
  readonly os_version: string | null
  readonly rapid_deploy: boolean
  readonly created: string
  readonly created_from: {
    readonly id: number
    readonly name: string
  } | null
  readonly bound_to: number | null
  readonly deleted: string | null
  readonly deprecated: string | null
  readonly labels: Record<string, string>
  readonly protection: {
    readonly delete: boolean
  }
}

/** A Hetzner Cloud block storage volume (used for ccache persistence). */
export interface Volume {
  readonly id: VolumeId
  readonly name: string
  readonly size: number
  readonly location: {
    readonly id: number
    readonly name: string
    readonly description: string
    readonly country: string
    readonly city: string
    readonly latitude: number
    readonly longitude: number
    readonly network_zone: string
  }
  readonly labels: Record<string, string>
  readonly linux_device: string | null
  readonly protection: {
    readonly delete: boolean
  }
  readonly server: number | null
  readonly created: string
}

/** Options for creating a new server via `hcloud server create`. */
export interface CreateServerOptions {
  readonly name: string
  readonly type: string
  readonly location: string
  readonly image: string | number
  readonly sshKeys?: readonly string[]
  readonly userData?: string
  readonly volumes?: readonly number[]
  readonly labels?: Record<string, string>
  /** When true, poll the API until the server status is "running". */
  readonly waitForRunning?: boolean
}

/** Options for creating a new volume via `hcloud volume create`. */
export interface CreateVolumeOptions {
  readonly name: string
  readonly size: number
  readonly location: string
  readonly labels?: Record<string, string>
  readonly format?: string
}

// ── Error types ─────────────────────────────────────────────────────────

/** API token could not be loaded from agenix or environment. */
export class HcloudTokenError extends Data.TaggedError("HcloudTokenError")<{
  readonly message: string
}> {}

/** getServer found no server with the given name or ID. */
export class HcloudServerNotFound extends Data.TaggedError("HcloudServerNotFound")<{
  readonly name: string
}> {}

/** deleteImage targeted an image ID that doesn't exist. */
export class HcloudImageNotFound extends Data.TaggedError("HcloudImageNotFound")<{
  readonly id: string | number
}> {}

/** deleteVolume / detachVolume targeted a volume name that doesn't exist. */
export class HcloudVolumeNotFound extends Data.TaggedError("HcloudVolumeNotFound")<{
  readonly name: string
}> {}

// ── Per-method error types ──────────────────────────────────────────────

/** getImage failed (not a "not found" — an API/network failure). */
export class HcloudGetImageError extends Data.TaggedError("HcloudGetImageError")<{
  readonly id: string | number
  readonly message: string
  readonly cause?: unknown
}> {}

/** getVolume failed (not a "not found" — an API/network failure). */
export class HcloudGetVolumeError extends Data.TaggedError("HcloudGetVolumeError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

/** listServers failed. */
export class HcloudListServersError extends Data.TaggedError("HcloudListServersError")<{
  readonly message: string
  readonly cause?: unknown
}> {}

/** getServer failed (not a "not found" — an API/network failure). */
export class HcloudGetServerError extends Data.TaggedError("HcloudGetServerError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

/** createServer failed. */
export class HcloudCreateServerError extends Data.TaggedError("HcloudCreateServerError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

/** deleteServer failed. */
export class HcloudDeleteServerError extends Data.TaggedError("HcloudDeleteServerError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

/** listImages failed. */
export class HcloudListImagesError extends Data.TaggedError("HcloudListImagesError")<{
  readonly message: string
  readonly cause?: unknown
}> {}

/** deleteImage failed (not a "not found" — an API/network failure). */
export class HcloudDeleteImageError extends Data.TaggedError("HcloudDeleteImageError")<{
  readonly id: string | number
  readonly message: string
  readonly cause?: unknown
}> {}

/** listVolumes failed. */
export class HcloudListVolumesError extends Data.TaggedError("HcloudListVolumesError")<{
  readonly message: string
  readonly cause?: unknown
}> {}

/** createVolume failed. */
export class HcloudCreateVolumeError extends Data.TaggedError("HcloudCreateVolumeError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

/** deleteVolume failed (not a "not found" — an API/network failure). */
export class HcloudDeleteVolumeError extends Data.TaggedError("HcloudDeleteVolumeError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

/** detachVolume failed (not a "not found" — an API/network failure). */
export class HcloudDetachVolumeError extends Data.TaggedError("HcloudDetachVolumeError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

// ── Service interface ───────────────────────────────────────────────────

/**
 * Service interface.  Consumers access it via `yield* HcloudService`.
 * The HcloudLive Layer binds ShellService internally so callers don't
 * need to provide it themselves.
 */
export interface HcloudServiceShape {
  /** List servers, optionally filtered by name, status, and/or label selector. */
  listServers(opts?: { name?: string; status?: Server["status"]; labels?: Record<string, string> }): Effect.Effect<readonly Server[], HcloudTokenError | HcloudListServersError>
  /** Find a server by name or ID. Uses the get-by-ID API when given a ServerId. */
  getServer(nameOrId: string | ServerId): Effect.Effect<Server, HcloudTokenError | HcloudServerNotFound | HcloudGetServerError>
  /** Check whether a server exists. */
  serverExists(nameOrId: string | ServerId): Effect.Effect<boolean, HcloudTokenError>
  /** Create a server from a snapshot with optional volumes and cloud-init user data. */
  createServer(opts: CreateServerOptions): Effect.Effect<Server, HcloudTokenError | HcloudCreateServerError>
  /** Delete a server by name. When `wait` is true, polls until the server is gone. */
  deleteServer(name: string, opts?: { wait?: boolean }): Effect.Effect<void, HcloudTokenError | HcloudServerNotFound | HcloudDeleteServerError>
  /** List images, optionally filtered by type ("snapshot") and/or label selector. */
  listImages(type?: string, labels?: Record<string, string>): Effect.Effect<readonly Image[], HcloudTokenError | HcloudListImagesError>
  /** Find an image by name or ID. Uses the get-by-ID API when given an ImageId. */
  getImage(nameOrId: string | ImageId): Effect.Effect<Image, HcloudTokenError | HcloudImageNotFound | HcloudGetImageError>
  /** Check whether an image exists. */
  imageExists(nameOrId: string | ImageId): Effect.Effect<boolean, HcloudTokenError>
  /** Delete an image by name or ID. Fails with HcloudImageNotFound if not found. */
  deleteImage(nameOrId: string | ImageId): Effect.Effect<void, HcloudTokenError | HcloudImageNotFound | HcloudDeleteImageError>
  /** List all volumes in the project. */
  listVolumes(): Effect.Effect<readonly Volume[], HcloudTokenError | HcloudListVolumesError>
  /** Find a volume by name or ID. Uses the get-by-ID API when given a VolumeId. */
  getVolume(nameOrId: string | VolumeId): Effect.Effect<Volume, HcloudTokenError | HcloudVolumeNotFound | HcloudGetVolumeError>
  /** Check whether a volume exists. */
  volumeExists(nameOrId: string | VolumeId): Effect.Effect<boolean, HcloudTokenError>
  /** Create an ext4-formatted volume at a specific location. */
  createVolume(opts: CreateVolumeOptions): Effect.Effect<Volume, HcloudTokenError | HcloudCreateVolumeError>
  /** Delete a volume by name or ID. Fails with HcloudVolumeNotFound if missing. */
  deleteVolume(nameOrId: string | VolumeId): Effect.Effect<void, HcloudTokenError | HcloudVolumeNotFound | HcloudDeleteVolumeError>
  /** Detach a volume from its server by name or ID. Fails with HcloudVolumeNotFound if missing. */
  detachVolume(nameOrId: string | VolumeId): Effect.Effect<void, HcloudTokenError | HcloudVolumeNotFound | HcloudDetachVolumeError>
}

export class HcloudService extends Context.Tag("HcloudService")<
  HcloudService,
  HcloudServiceShape
>() {}

// ── Implementation ──────────────────────────────────────────────────────

/** In-process token cache — avoids re-reading the file on every API call. */
let cachedToken: string | null = null

/**
 * Load the Hetzner API token.
 *
 * Priority:
 *   1. In-process cache (fastest)
 *   2. /run/agenix/hetzner-api-token (agenix-decrypted secret on NixOS)
 *   3. HCLOUD_TOKEN environment variable (CI / dev fallback)
 *
 * Fails with HcloudTokenError if none of the above yields a non-empty token.
 */
const loadHcloudToken = (fs: FileSystem.FileSystem): Effect.Effect<string, HcloudTokenError> =>
  Effect.gen(function* () {
    if (cachedToken) return cachedToken

    const token = yield* fs.readFileString("/run/agenix/hetzner-api-token").pipe(
      Effect.map(s => s.trim()),
      Effect.catchAll(() => {
        const envToken = process.env.HCLOUD_TOKEN
        if (envToken) return Effect.succeed(envToken)
        return Effect.fail(new HcloudTokenError({
          message: "HCLOUD_TOKEN not found in environment and /run/agenix/hetzner-api-token not readable"
        }))
      })
    )

    cachedToken = token
    return token
  })

const makeHcloudService = (fs: FileSystem.FileSystem): HcloudServiceShape => {
  const listServers: HcloudServiceShape["listServers"] = (opts) => Effect.gen(function* () {
    const token = yield* loadHcloudToken(fs)
    const servers: Server[] = []
    let page = 1

    const params = new URLSearchParams({ per_page: "50" })
    if (opts?.name) params.set("name", opts.name)
    if (opts?.status) params.set("status", opts.status)
    if (opts?.labels) {
      params.set("label_selector", Object.entries(opts.labels).map(([k, v]) => `${k}=${v}`).join(","))
    }

    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition -- pagination loop
    while (true) {
      params.set("page", String(page))
      const response = yield* Effect.tryPromise({
        try: () => fetch(`https://api.hetzner.cloud/v1/servers?${params.toString()}`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
        catch: (e) => new HcloudListServersError({ message: "Request failed", cause: e }),
      })

      const json = yield* Effect.tryPromise({
        try: () => response.json() as Promise<{
          servers: Server[]
          meta: { pagination: { next_page: number | null } }
        }>,
        catch: (e) => new HcloudListServersError({ message: `Failed to parse API response (HTTP ${response.status})`, cause: e }),
      })

      if (!response.ok) {
        return yield* Effect.fail(new HcloudListServersError({ message: `HTTP ${response.status}` }))
      }

      servers.push(...json.servers)

      if (json.meta.pagination.next_page === null) break
      page = json.meta.pagination.next_page
    }

    return servers
  })

  const getServer: HcloudServiceShape["getServer"] = (nameOrId) => Effect.gen(function* () {
    if (typeof nameOrId === "number") {
      const token = yield* loadHcloudToken(fs)
      const name = String(nameOrId)
      const response = yield* Effect.tryPromise({
        try: () => fetch(`https://api.hetzner.cloud/v1/servers/${nameOrId}`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
        catch: (e) => new HcloudGetServerError({ name, message: "Request failed", cause: e }),
      })

      if (response.status === 404) {
        return yield* Effect.fail(new HcloudServerNotFound({ name }))
      }

      const json = yield* Effect.tryPromise({
        try: () => response.json() as Promise<{ server?: Server; error?: { message: string } }>,
        catch: (e) => new HcloudGetServerError({ name, message: `Failed to parse API response (HTTP ${response.status})`, cause: e }),
      })

      if (!response.ok || !json.server) {
        return yield* Effect.fail(new HcloudGetServerError({ name, message: json.error?.message ?? `HTTP ${response.status}` }))
      }

      return json.server
    }

    const servers = yield* listServers({ name: nameOrId }).pipe(
      Effect.catchTag("HcloudListServersError", (e) => Effect.fail(new HcloudGetServerError({ name: nameOrId, message: "Failed to list servers", cause: e })))
    )
    const server = servers.find(s => s.name === nameOrId)
    if (!server) {
      return yield* Effect.fail(new HcloudServerNotFound({ name: nameOrId }))
    }
    return server
  })

  const listImages: HcloudServiceShape["listImages"] = (type, labels) => Effect.gen(function* () {
    const token = yield* loadHcloudToken(fs)
    const images: Image[] = []
    let page = 1

    const params = new URLSearchParams({ per_page: "50" })
    if (type) params.set("type", type)
    if (labels) {
      params.set("label_selector", Object.entries(labels).map(([k, v]) => `${k}=${v}`).join(","))
    }

    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition -- pagination loop
    while (true) {
      params.set("page", String(page))
      const response = yield* Effect.tryPromise({
        try: () => fetch(`https://api.hetzner.cloud/v1/images?${params.toString()}`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
        catch: (e) => new HcloudListImagesError({ message: "Request failed", cause: e }),
      })

      const json = yield* Effect.tryPromise({
        try: () => response.json() as Promise<{
          images: Image[]
          meta: { pagination: { next_page: number | null } }
        }>,
        catch: (e) => new HcloudListImagesError({ message: `Failed to parse API response (HTTP ${response.status})`, cause: e }),
      })

      if (!response.ok) {
        return yield* Effect.fail(new HcloudListImagesError({ message: `HTTP ${response.status}` }))
      }

      images.push(...json.images)

      if (json.meta.pagination.next_page === null) break
      page = json.meta.pagination.next_page
    }

    return images
  })

  const getImage: HcloudServiceShape["getImage"] = (nameOrId) => Effect.gen(function* () {
    if (typeof nameOrId === "number") {
      const token = yield* loadHcloudToken(fs)
      const id = String(nameOrId)
      const response = yield* Effect.tryPromise({
        try: () => fetch(`https://api.hetzner.cloud/v1/images/${nameOrId}`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
        catch: (e) => new HcloudGetImageError({ id: nameOrId, message: "Request failed", cause: e }),
      })

      if (response.status === 404) {
        return yield* Effect.fail(new HcloudImageNotFound({ id }))
      }

      const json = yield* Effect.tryPromise({
        try: () => response.json() as Promise<{ image?: Image; error?: { message: string } }>,
        catch: (e) => new HcloudGetImageError({ id: nameOrId, message: `Failed to parse API response (HTTP ${response.status})`, cause: e }),
      })

      if (!response.ok || !json.image) {
        return yield* Effect.fail(new HcloudGetImageError({ id: nameOrId, message: json.error?.message ?? `HTTP ${response.status}` }))
      }

      return json.image
    }

    const images = yield* listImages().pipe(
      Effect.catchTag("HcloudListImagesError", (e) => Effect.fail(new HcloudGetImageError({ id: nameOrId, message: "Failed to list images", cause: e })))
    )
    const image = images.find(i => i.name === nameOrId)
    if (!image) {
      return yield* Effect.fail(new HcloudImageNotFound({ id: nameOrId }))
    }
    return image
  })

  const getVolume: HcloudServiceShape["getVolume"] = (nameOrId) => Effect.gen(function* () {
    if (typeof nameOrId === "number") {
      const token = yield* loadHcloudToken(fs)
      const name = String(nameOrId)
      const response = yield* Effect.tryPromise({
        try: () => fetch(`https://api.hetzner.cloud/v1/volumes/${nameOrId}`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
        catch: (e) => new HcloudGetVolumeError({ name, message: "Request failed", cause: e }),
      })

      if (response.status === 404) {
        return yield* Effect.fail(new HcloudVolumeNotFound({ name }))
      }

      const json = yield* Effect.tryPromise({
        try: () => response.json() as Promise<{ volume?: Volume; error?: { message: string } }>,
        catch: (e) => new HcloudGetVolumeError({ name, message: `Failed to parse API response (HTTP ${response.status})`, cause: e }),
      })

      if (!response.ok || !json.volume) {
        return yield* Effect.fail(new HcloudGetVolumeError({ name, message: json.error?.message ?? `HTTP ${response.status}` }))
      }

      return json.volume
    }

    const token = yield* loadHcloudToken(fs)
    const params = new URLSearchParams({ name: nameOrId, per_page: "1" })
    const response = yield* Effect.tryPromise({
      try: () => fetch(`https://api.hetzner.cloud/v1/volumes?${params.toString()}`, {
        headers: { Authorization: `Bearer ${token}` },
      }),
      catch: (e) => new HcloudGetVolumeError({ name: nameOrId, message: "Request failed", cause: e }),
    })

    const json = yield* Effect.tryPromise({
      try: () => response.json() as Promise<{ volumes: Volume[] }>,
      catch: (e) => new HcloudGetVolumeError({ name: nameOrId, message: `Failed to parse API response (HTTP ${response.status})`, cause: e }),
    })

    const volume = json.volumes.find(v => v.name === nameOrId)
    if (!volume) {
      return yield* Effect.fail(new HcloudVolumeNotFound({ name: nameOrId }))
    }
    return volume
  })

  return {
  listServers,
  getServer,
  serverExists: (nameOrId) => getServer(nameOrId).pipe(
    Effect.map(() => true),
    Effect.catchTags({
      HcloudServerNotFound: () => Effect.succeed(false),
      HcloudGetServerError: () => Effect.succeed(false),
    })
  ),

  createServer: (opts: CreateServerOptions) => Effect.gen(function* () {
    const token = yield* loadHcloudToken(fs)

    const body: Record<string, unknown> = {
      name: opts.name,
      server_type: opts.type,
      location: opts.location,
      image: opts.image,
    }
    if (opts.sshKeys && opts.sshKeys.length > 0) body.ssh_keys = [...opts.sshKeys]
    if (opts.userData) body.user_data = opts.userData
    if (opts.volumes && opts.volumes.length > 0) body.volumes = [...opts.volumes]
    if (opts.labels) body.labels = opts.labels

    const response = yield* Effect.tryPromise({
      try: () => fetch("https://api.hetzner.cloud/v1/servers", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      }),
      catch: (e) => new HcloudCreateServerError({ name: opts.name, message: "Request failed", cause: e }),
    })

    const json = yield* Effect.tryPromise({
      try: () => response.json() as Promise<{ server?: Server; error?: { message: string; code: string } }>,
      catch: (e) => new HcloudCreateServerError({ name: opts.name, message: `Failed to parse API response (HTTP ${response.status})`, cause: e }),
    })

    if (!response.ok || !json.server) {
      return yield* Effect.fail(new HcloudCreateServerError({
        name: opts.name,
        message: json.error?.message ?? `HTTP ${response.status}`,
      }))
    }

    if (!opts.waitForRunning) return json.server

    // Poll GET /v1/servers/{id} until status is "running"
    const serverId = json.server.id
    const pollOnce = Effect.gen(function* () {
      const pollResponse = yield* Effect.tryPromise({
        try: () => fetch(`https://api.hetzner.cloud/v1/servers/${serverId}`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
        catch: (e) => new HcloudCreateServerError({ name: opts.name, message: "Poll request failed", cause: e }),
      })

      const pollJson = yield* Effect.tryPromise({
        try: () => pollResponse.json() as Promise<{ server?: Server }>,
        catch: (e) => new HcloudCreateServerError({ name: opts.name, message: `Failed to parse poll response (HTTP ${pollResponse.status})`, cause: e }),
      })

      if (pollJson.server?.status !== "running") {
        return yield* Effect.fail(new HcloudCreateServerError({ name: opts.name, message: "Not running yet" }))
      }
      return pollJson.server
    })

    return yield* pollOnce.pipe(
      Effect.retry(Schedule.spaced("5 seconds").pipe(Schedule.intersect(Schedule.recurs(59)))),
      Effect.catchTag("HcloudCreateServerError", () => Effect.fail(new HcloudCreateServerError({
        name: opts.name,
        message: `Server did not reach 'running' status within 300s`,
      })))
    )
  }),

  deleteServer: (name: string, opts?: { wait?: boolean }) => Effect.gen(function* () {
    const server = yield* getServer(name).pipe(
      Effect.catchTag("HcloudGetServerError", (e) => Effect.fail(new HcloudDeleteServerError({ name, message: "Failed to look up server", cause: e })))
    )

    if (server.status !== "deleting") {
      const token = yield* loadHcloudToken(fs)
      const serverId = server.id

      const deleteResponse = yield* Effect.tryPromise({
        try: () => fetch(`https://api.hetzner.cloud/v1/servers/${serverId}`, {
          method: "DELETE",
          headers: { Authorization: `Bearer ${token}` },
        }),
        catch: (e) => new HcloudDeleteServerError({ name, message: "Request failed", cause: e }),
      })

      if (!deleteResponse.ok) {
        const errorJson = yield* Effect.tryPromise({
          try: () => deleteResponse.json() as Promise<{ error?: { message: string } }>,
          catch: (e) => new HcloudDeleteServerError({ name, message: `HTTP ${deleteResponse.status}`, cause: e }),
        })
        return yield* Effect.fail(new HcloudDeleteServerError({
          name,
          message: errorJson.error?.message ?? `HTTP ${deleteResponse.status}`,
        }))
      }
    }

    if (!opts?.wait) return

    // Poll until the server is gone
    yield* getServer(name).pipe(
      Effect.flatMap(() => Effect.fail("still exists" as const)),
      Effect.catchTag("HcloudServerNotFound", () => Effect.void),
      Effect.catchTag("HcloudGetServerError", () => Effect.fail("still exists" as const)),
      Effect.retry(Schedule.spaced("3 seconds").pipe(Schedule.upTo("120 seconds"))),
      Effect.catchAll(() => Effect.fail(new HcloudDeleteServerError({
        name,
        message: "Server did not disappear within 120s",
      }))),
    )
  }),

  listImages,
  getImage,
  imageExists: (nameOrId) => getImage(nameOrId).pipe(
    Effect.map(() => true),
    Effect.catchTags({
      HcloudImageNotFound: () => Effect.succeed(false),
      HcloudGetImageError: () => Effect.succeed(false),
    })
  ),

  deleteImage: (nameOrId: string | ImageId) => Effect.gen(function* () {
    const image = yield* getImage(nameOrId).pipe(
      Effect.catchTag("HcloudGetImageError", (e) => Effect.fail(new HcloudDeleteImageError({ id: nameOrId, message: "Failed to look up image", cause: e })))
    )

    const token = yield* loadHcloudToken(fs)
    const response = yield* Effect.tryPromise({
      try: () => fetch(`https://api.hetzner.cloud/v1/images/${image.id}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${token}` },
      }),
      catch: (e) => new HcloudDeleteImageError({ id: nameOrId, message: "Request failed", cause: e }),
    })

    if (!response.ok) {
      const errorJson = yield* Effect.tryPromise({
        try: () => response.json() as Promise<{ error?: { message: string } }>,
        catch: (e) => new HcloudDeleteImageError({ id: nameOrId, message: `HTTP ${response.status}`, cause: e }),
      })
      return yield* Effect.fail(new HcloudDeleteImageError({
        id: nameOrId,
        message: errorJson.error?.message ?? `HTTP ${response.status}`,
      }))
    }
  }),

  listVolumes: () => Effect.gen(function* () {
    const token = yield* loadHcloudToken(fs)
    const volumes: Volume[] = []
    let page = 1

    const params = new URLSearchParams({ per_page: "50" })

    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition -- pagination loop
    while (true) {
      params.set("page", String(page))
      const response = yield* Effect.tryPromise({
        try: () => fetch(`https://api.hetzner.cloud/v1/volumes?${params.toString()}`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
        catch: (e) => new HcloudListVolumesError({ message: "Request failed", cause: e }),
      })

      const json = yield* Effect.tryPromise({
        try: () => response.json() as Promise<{
          volumes: Volume[]
          meta: { pagination: { next_page: number | null } }
        }>,
        catch: (e) => new HcloudListVolumesError({ message: `Failed to parse API response (HTTP ${response.status})`, cause: e }),
      })

      if (!response.ok) {
        return yield* Effect.fail(new HcloudListVolumesError({ message: `HTTP ${response.status}` }))
      }

      volumes.push(...json.volumes)

      if (json.meta.pagination.next_page === null) break
      page = json.meta.pagination.next_page
    }

    return volumes
  }),

  getVolume,
  volumeExists: (nameOrId) => getVolume(nameOrId).pipe(
    Effect.map(() => true),
    Effect.catchTags({
      HcloudVolumeNotFound: () => Effect.succeed(false),
      HcloudGetVolumeError: () => Effect.succeed(false),
    })
  ),

  createVolume: (opts: CreateVolumeOptions) => Effect.gen(function* () {
    const token = yield* loadHcloudToken(fs)

    const body: Record<string, unknown> = {
      name: opts.name,
      size: opts.size,
      location: opts.location,
    }
    if (opts.format) body.format = opts.format
    if (opts.labels) body.labels = opts.labels

    const response = yield* Effect.tryPromise({
      try: () => fetch("https://api.hetzner.cloud/v1/volumes", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      }),
      catch: (e) => new HcloudCreateVolumeError({ name: opts.name, message: "Request failed", cause: e }),
    })

    const json = yield* Effect.tryPromise({
      try: () => response.json() as Promise<{ volume?: Volume; error?: { message: string } }>,
      catch: (e) => new HcloudCreateVolumeError({ name: opts.name, message: `Failed to parse API response (HTTP ${response.status})`, cause: e }),
    })

    if (!response.ok || !json.volume) {
      return yield* Effect.fail(new HcloudCreateVolumeError({
        name: opts.name,
        message: json.error?.message ?? `HTTP ${response.status}`,
      }))
    }

    return json.volume
  }),

  deleteVolume: (nameOrId: string | VolumeId) => Effect.gen(function* () {
    const displayName = String(nameOrId)
    const volume = yield* getVolume(nameOrId).pipe(
      Effect.catchTag("HcloudGetVolumeError", (e) => Effect.fail(new HcloudDeleteVolumeError({ name: displayName, message: "Failed to look up volume", cause: e })))
    )

    const token = yield* loadHcloudToken(fs)
    const response = yield* Effect.tryPromise({
      try: () => fetch(`https://api.hetzner.cloud/v1/volumes/${volume.id}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${token}` },
      }),
      catch: (e) => new HcloudDeleteVolumeError({ name: displayName, message: "Request failed", cause: e }),
    })

    if (!response.ok) {
      const errorJson = yield* Effect.tryPromise({
        try: () => response.json() as Promise<{ error?: { message: string } }>,
        catch: (e) => new HcloudDeleteVolumeError({ name: displayName, message: `HTTP ${response.status}`, cause: e }),
      })
      return yield* Effect.fail(new HcloudDeleteVolumeError({
        name: displayName,
        message: errorJson.error?.message ?? `HTTP ${response.status}`,
      }))
    }
  }),

  detachVolume: (nameOrId: string | VolumeId) => Effect.gen(function* () {
    const displayName = String(nameOrId)
    const volume = yield* getVolume(nameOrId).pipe(
      Effect.catchTag("HcloudGetVolumeError", (e) => Effect.fail(new HcloudDetachVolumeError({ name: displayName, message: "Failed to look up volume", cause: e })))
    )

    const token = yield* loadHcloudToken(fs)
    const response = yield* Effect.tryPromise({
      try: () => fetch(`https://api.hetzner.cloud/v1/volumes/${volume.id}/actions/detach`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
      }),
      catch: (e) => new HcloudDetachVolumeError({ name: displayName, message: "Request failed", cause: e }),
    })

    if (!response.ok) {
      const errorJson = yield* Effect.tryPromise({
        try: () => response.json() as Promise<{ error?: { message: string } }>,
        catch: (e) => new HcloudDetachVolumeError({ name: displayName, message: `HTTP ${response.status}`, cause: e }),
      })
      return yield* Effect.fail(new HcloudDetachVolumeError({
        name: displayName,
        message: errorJson.error?.message ?? `HTTP ${response.status}`,
      }))
    }
  })
}}

export const HcloudLive = Layer.effect(
  HcloudService,
  Effect.gen(function* () {
    const fs = yield* FileSystem.FileSystem
    return makeHcloudService(fs)
  })
)
