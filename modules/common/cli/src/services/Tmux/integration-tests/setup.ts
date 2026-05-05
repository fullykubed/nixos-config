import { Effect, Layer } from "effect"
import { ShellLive, ShellService } from "../../Shell"

/**
 * ShellService layer that intercepts `exec("tmux", ...)` calls to inject
 * `-L <socket> -f /dev/null`, routing all tmux commands to an isolated server
 * with default config (no plugins, base-index 0, pane-base-index 0).
 */
export const makeIsolatedTmuxShell = (socketName: string) => {
  const prefix = ["-L", socketName, "-f", "/dev/null"] as const
  return Layer.effect(
    ShellService,
    Effect.gen(function* () {
      const real = yield* ShellService
      return ShellService.of({
        exec: (cmd, args, opts) =>
          cmd === "tmux"
            ? real.exec("tmux", [...prefix, ...args], opts)
            : real.exec(cmd, args, opts),
        execJson: (cmd, args) =>
          cmd === "tmux"
            ? real.execJson("tmux", [...prefix, ...args])
            : real.execJson(cmd, args),
        execLines: (cmd, args) =>
          cmd === "tmux"
            ? real.execLines("tmux", [...prefix, ...args])
            : real.execLines(cmd, args),
      })
    }),
  ).pipe(Layer.provide(ShellLive))
}
