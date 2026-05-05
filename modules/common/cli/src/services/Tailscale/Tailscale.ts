import { Context, Effect, Layer } from "effect"
import { FileSystem, HttpClient } from "@effect/platform"
import { ShellService } from "../Shell"
import { mkContextInjector } from "../../lib/mkContextInjector"
import { status } from "./public/status"
import { resolveIP } from "./public/resolve-ip"
import { findPeer } from "./public/find-peer"
import { mintPreAuthKey } from "./public/mint-pre-auth-key"
import { deleteNode } from "./public/delete-node"
import { isReachable } from "./public/is-reachable"

// Re-exports
export {
  TailscaleNotConnectedError,
  TailscaleDNSResolutionError,
  HeadscalePreAuthError,
  HeadscaleNodeError,
} from "./errors"
export type { TailscaleStatus } from "./types"

const make = Effect.gen(function* () {
  const shell = yield* ShellService
  const fs = yield* FileSystem.FileSystem
  const http = yield* HttpClient.HttpClient
  const ctx = Context.empty().pipe(
    Context.add(ShellService, shell),
    Context.add(FileSystem.FileSystem, fs),
    Context.add(HttpClient.HttpClient, http),
  )
  const inject = mkContextInjector(ctx, "Tailscale")

  return {
    status: inject(status),
    resolveIP: inject(resolveIP),
    findPeer: inject(findPeer),
    mintPreAuthKey: inject(mintPreAuthKey),
    deleteNode: inject(deleteNode),
    isReachable: inject(isReachable),
  }
})

export type TailscaleServiceShape = Effect.Effect.Success<typeof make>

export class TailscaleService extends Context.Tag("TailscaleService")<
  TailscaleService,
  TailscaleServiceShape
>() {}

export const TailscaleLive = Layer.effect(TailscaleService, make)
