import { Context, Effect, Layer } from "effect"
import { FileSystem } from "@effect/platform"
import { mkContextInjector } from "../../lib/mkContextInjector"
import { HcloudService } from "../Hcloud"
import { TailscaleService } from "../Tailscale"
import { SshService } from "../Ssh"
import { ShellService } from "../Shell"
import { CrocService } from "../Croc"
import { LockService } from "../Lock"
import { resolve } from "./public/resolve"
import { list } from "./public/list"
import { get } from "./public/get"
import { exists } from "./public/exists"
import { resolveIP } from "./public/resolve-ip"
import { isReady } from "./public/is-ready"
import { getAge } from "./public/get-age"
import { destroy } from "./public/destroy"
import { create } from "./public/create"
import { getStats } from "./public/get-stats"

// ── Re-exports ───────────────────────────────────────────────────────

export type { BuilderStats } from "./types"

// ── Service ──────────────────────────────────────────────────────────

const make = Effect.gen(function* () {
  const hcloud = yield* HcloudService
  const tailscale = yield* TailscaleService
  const ssh = yield* SshService
  const shell = yield* ShellService
  const croc = yield* CrocService
  const fs = yield* FileSystem.FileSystem
  const lock = yield* LockService

  const ctx = Context.empty().pipe(
    Context.add(HcloudService, hcloud),
    Context.add(TailscaleService, tailscale),
    Context.add(SshService, ssh),
    Context.add(ShellService, shell),
    Context.add(CrocService, croc),
    Context.add(FileSystem.FileSystem, fs),
    Context.add(LockService, lock),
  )
  const inject = mkContextInjector(ctx)

  return {
    resolve,
    list: inject(list),
    get: inject(get),
    exists: inject(exists),
    resolveIP: inject(resolveIP),
    isReady: inject(isReady),
    getAge: inject(getAge),
    destroy: inject(destroy),
    create: inject(create),
    getStats: inject(getStats),
  }
})

export type BuildersServiceShape = Effect.Effect.Success<typeof make>

export class BuildersService extends Context.Tag("BuildersService")<
  BuildersService,
  BuildersServiceShape
>() {}

export const BuildersLive = Layer.effect(BuildersService, make)
