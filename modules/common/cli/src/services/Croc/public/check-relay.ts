import { Effect } from "effect"
import { ShellService } from "../../Shell"
import { CrocRelayUnreachableError } from "../errors"
import { RELAY_ADDRESS } from "../config"

export const checkRelay = () =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const [host, port] = RELAY_ADDRESS.split(":")
    yield* shell.exec("nc", ["-z", "-w", "2", host!, port!]).pipe(
      Effect.asVoid,
      Effect.catchAll(() => Effect.fail(new CrocRelayUnreachableError({ relayAddress: RELAY_ADDRESS })))
    )
  })