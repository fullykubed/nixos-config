import { Layer } from "effect"
import { BunContext } from "@effect/platform-bun"
import { ShellLive } from "./Shell"
import { StoreLive } from "./Store"
import { LockLive } from "./Lock"
import { HcloudLive } from "./Hcloud"
import { TailscaleLive } from "./Tailscale"
import { SshLive } from "./Ssh"
import { CrocLive } from "./Croc"
import { BuildersLive } from "./Builders"

/** Shell + BunContext (FileSystem, Path, CommandExecutor). */
export const BaseLive = ShellLive.pipe(
  Layer.provideMerge(BunContext.layer)
)

/** HcloudService + everything in BaseLive. */
export const HcloudFullLive = HcloudLive.pipe(
  Layer.provideMerge(BaseLive)
)

/** BuildersService + every transitive dependency, merged so handlers
 *  can directly yield* ShellService, SshService, TailscaleService,
 *  LockService, FileSystem, etc. */
export const BuildersFullLive = Layer.mergeAll(
  ShellLive,
  StoreLive,
  LockLive.pipe(
    Layer.provide(StoreLive),
  ),
  HcloudLive,
  TailscaleLive,
  SshLive,
  CrocLive,
  BuildersLive.pipe(
    Layer.provide(HcloudLive),
    Layer.provide(TailscaleLive),
    Layer.provide(SshLive),
    Layer.provide(CrocLive),
    Layer.provide(LockLive.pipe(Layer.provide(StoreLive))),
  )
).pipe(
  Layer.provide(ShellLive),
  Layer.provideMerge(BunContext.layer)
)
