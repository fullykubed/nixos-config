import { Context, Effect, Layer } from "effect"
import { FileSystem } from "@effect/platform"
import { ShellService } from "../Shell"
import { mkContextInjector } from "../../lib/mkContextInjector"
import { RELAY_ADDRESS } from "./config"
import { checkRelay } from "./public/check-relay"
import { generateCode } from "./public/generate-code"
import { readRelayPass } from "./public/read-relay-pass"
import { send } from "./public/send"

export {
  CrocRelayUnreachableError,
  CrocRelayPassError,
  CrocCodeError,
  CrocSendError,
} from "./errors"

const make = Effect.gen(function* () {
  const shell = yield* ShellService
  const fs = yield* FileSystem.FileSystem

  const ctx = Context.empty().pipe(
    Context.add(ShellService, shell),
    Context.add(FileSystem.FileSystem, fs),
  )
  const inject = mkContextInjector(ctx, "Croc")

  return {
    relayAddress: RELAY_ADDRESS,
    checkRelay: inject(checkRelay),
    generateCode: inject(generateCode),
    readRelayPass: inject(readRelayPass),
    send: inject(send),
  }
})

export type CrocServiceShape = Effect.Effect.Success<typeof make>

export class CrocService extends Context.Tag("CrocService")<
  CrocService,
  CrocServiceShape
>() {}

export const CrocLive = Layer.effect(CrocService, make)
