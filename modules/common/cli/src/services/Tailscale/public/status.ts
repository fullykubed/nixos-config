import { Effect } from "effect"
import { ShellService } from "../../Shell"
import { TailscaleNotConnectedError } from "../errors"
import type { TailscaleStatus } from "../types"

export const status = () =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const statusResult = yield* shell.execJson<TailscaleStatus>("tailscale", ["status", "--json"])
    if (statusResult.BackendState !== "Running") {
      yield* Effect.fail(new TailscaleNotConnectedError({
        backendState: statusResult.BackendState,
        message: `Tailscale is not running (state: ${statusResult.BackendState})`
      }))
    }
    return statusResult
  })