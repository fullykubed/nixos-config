import { Effect } from "effect"
import { ShellService } from "../../Shell"
import { CrocCodeError } from "../errors"

export const generateCode = () =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    return yield* shell.exec("openssl", ["rand", "-hex", "16"]).pipe(
      Effect.map(result => result.stdout.trim()),
      Effect.catchAll(() => Effect.fail(new CrocCodeError({ message: "Failed to generate croc code via openssl" })))
    )
  })