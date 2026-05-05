import { Context, Effect } from "effect"
import { FileSystem } from "@effect/platform"
import {
  HcloudService,
  ServerId,
  ImageId,
  VolumeId,
  HcloudServerNotFound,
  type HcloudServiceShape,
  type Server,
  type Image,
  type Volume,
} from "../Hcloud"
import { TailscaleService, type TailscaleServiceShape } from "../Tailscale"
import { SshService, type SshServiceShape } from "../Ssh"
import { CrocService, type CrocServiceShape } from "../Croc"
import { LockService, type LockServiceShape } from "../Lock"

// ── Fixtures ────────────────────────────────────────────────────────

export const youngServer: Server = {
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

// ── Mock factories ───────────────────────────────────────────────────

export const baseHcloud = (overrides: Partial<HcloudServiceShape> = {}): HcloudServiceShape => ({
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

export const baseTailscale = (overrides: Partial<TailscaleServiceShape> = {}): TailscaleServiceShape => ({
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

export const baseLock: LockServiceShape = {
  isLocked: () => Effect.succeed(false),
  acquire: () => Effect.succeed({ waited: false, attempts: 1 }),
  release: () => Effect.void,
   
  withLock: (_name, f) => f({ waited: false, attempts: 1 }) as any,
}

const mockFs = FileSystem.FileSystem.of({
  exists: () => Effect.succeed(true),
  readFileString: () => Effect.succeed("mock-secret-content"),
  makeTempFileScoped: () => Effect.succeed("/tmp/mock-install-script"),
  writeFileString: () => Effect.void,
} as unknown as FileSystem.FileSystem)

// ── Context builder for multi-service tests ──────────────────────────

export function makeTestContext(opts: {
  hcloud?: Partial<HcloudServiceShape>
  tailscale?: Partial<TailscaleServiceShape>
  croc?: Partial<CrocServiceShape>
  ssh?: SshServiceShape
  lock?: LockServiceShape
  fs?: FileSystem.FileSystem
}) {
  return Context.empty().pipe(
    Context.add(HcloudService, baseHcloud(opts.hcloud)),
    Context.add(TailscaleService, baseTailscale(opts.tailscale)),
    Context.add(SshService, opts.ssh ?? baseSsh),
    Context.add(CrocService, baseCroc(opts.croc)),
    Context.add(LockService, opts.lock ?? baseLock),
    Context.add(FileSystem.FileSystem, opts.fs ?? mockFs),
  )
}
