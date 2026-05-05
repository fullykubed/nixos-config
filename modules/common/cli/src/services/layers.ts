/**
 * Layer composition: ready-to-use bundles of service layers.
 *
 * `Layer.provideMerge` both satisfies a layer's requirements AND merges its
 * output into the final context, so command handlers can `yield*` any service
 * in the stack.
 *
 * Order is bottom-up: platform layers first (rightmost in the pipe chain),
 * then infrastructure services, then domain services. Each `provideMerge`
 * call satisfies the requirements of the layers above it while keeping its
 * own output available to command handlers.
 */
import { Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { FetchHttpClient } from "@effect/platform"
import { ShellLive } from "./Shell"
import { StoreLive } from "./Store"
import { LockLive } from "./Lock"
import { HcloudLive } from "./Hcloud"
import { TailscaleLive } from "./Tailscale"
import { SshLive } from "./Ssh"
import { CrocLive } from "./Croc"
import { BuildersLive } from "./Builders"
import { TmuxLive } from "./Tmux"
import { GitLive } from "./Git"
import { MuxLive } from "./Mux"

/** Shell + BunContext (FileSystem, Path, CommandExecutor) + FetchHttpClient. */
export const BaseLive = ShellLive.pipe(
  Layer.provideMerge(FetchHttpClient.layer),
  Layer.provideMerge(BunContext.layer)
)

/** HcloudService + everything in BaseLive. */
export const HcloudFullLive = HcloudLive.pipe(
  Layer.provideMerge(BaseLive)
)

/** BuildersService + every transitive dependency, merged so handlers
 *  can directly yield* ShellService, SshService, TailscaleService,
 *  LockService, FileSystem, etc.
 *
 *  Each provideMerge satisfies requirements AND merges the output into
 *  the final context. Order is bottom-up: platform → Shell → domain → Builders. */
export const BuildersFullLive = BuildersLive.pipe(
  Layer.provideMerge(LockLive),
  Layer.provideMerge(StoreLive),
  Layer.provideMerge(CrocLive),
  Layer.provideMerge(SshLive),
  Layer.provideMerge(TailscaleLive),
  Layer.provideMerge(HcloudLive),
  Layer.provideMerge(ShellLive),
  Layer.provideMerge(FetchHttpClient.layer),
  Layer.provideMerge(BunContext.layer),
)

/** MuxService + every dependency, merged so handlers
 *  can directly yield* MuxService, TmuxService, GitService, ShellService,
 *  StoreService, FileSystem, etc. */
export const MuxFullLive = MuxLive.pipe(
  Layer.provideMerge(TmuxLive),
  Layer.provideMerge(GitLive),
  Layer.provideMerge(StoreLive),
  Layer.provideMerge(ShellLive),
  Layer.provideMerge(BunContext.layer),
)
