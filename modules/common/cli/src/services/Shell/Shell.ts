import { Context, Effect, Layer } from "effect"
import { CommandExecutor } from "@effect/platform"
import { mkContextInjector } from "../../lib/mkContextInjector"
import { exec } from "./public/exec"
import { execJson } from "./public/exec-json"
import { execLines } from "./public/exec-lines"

// ── Re-exports ───────────────────────────────────────────────────────

export { ShellError, JsonParseError } from "./errors"

// ── Service ──────────────────────────────────────────────────────────

const make = Effect.gen(function* () {
  const executor = yield* CommandExecutor.CommandExecutor

  const ctx = Context.empty().pipe(Context.add(CommandExecutor.CommandExecutor, executor))
  const inject = mkContextInjector(ctx, "Shell")
  const provide = Effect.provide(ctx)

  return {
    exec: inject(exec),
    execJson: <T>(cmd: string, args: readonly string[]) => provide(execJson<T>(cmd, args)),
    execLines: inject(execLines),
  }
})

export type ShellServiceShape = Effect.Effect.Success<typeof make>

export class ShellService extends Context.Tag("ShellService")<
  ShellService,
  ShellServiceShape
>() {}

export const ShellLive = Layer.effect(ShellService, make)
