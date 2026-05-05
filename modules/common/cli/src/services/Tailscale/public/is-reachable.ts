import { Effect } from "effect"
import { ShellService } from "../../Shell"

export const isReachable = (hostname: string, port: number) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    return yield* shell.exec("nc", ["-z", "-w", "3", hostname, port.toString()]).pipe(
      Effect.map(() => true),
      Effect.catchAll(() => Effect.succeed(false))
    )
  })