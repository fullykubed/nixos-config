import { Context, Effect, Layer } from "effect"
import { ShellService } from "../Shell"
import { mkContextInjector } from "../../lib/mkContextInjector"
import { exec } from "./public/exec"
import { interactive } from "./public/interactive"

export { SshConnectionError, SshAuthError, SshTimeoutError, SshHostKeyError } from "./errors"

const make = Effect.gen(function* () {
  const shell = yield* ShellService
  const ctx = Context.empty().pipe(Context.add(ShellService, shell))
  const inject = mkContextInjector(ctx, "Ssh")

  return {
    exec: inject(exec),
    interactive,
  }
})

export type SshServiceShape = Effect.Effect.Success<typeof make>

export class SshService extends Context.Tag("SshService")<
  SshService,
  SshServiceShape
>() {}

export const SshLive = Layer.effect(SshService, make)
