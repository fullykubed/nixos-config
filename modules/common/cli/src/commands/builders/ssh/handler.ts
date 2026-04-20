import { Effect } from "effect"
import type { ParsedCommand } from "../../../cli/types"
import { BuildersService } from "../../../services/Builders"
import { SshService } from "../../../services/Ssh"
import { setupHostKeyVerification } from "./setup-host-key"
import { parseRemoteCommand } from "./parse-remote-command"

export const sshHandler = (parsed: ParsedCommand) =>
  Effect.gen(function* () {
    const nameArg = parsed.args[0]
    const isRoot = parsed.flags.get("root") === true

    if (!nameArg) {
      yield* Effect.logError("Usage: j builders ssh <name|N> [--root] [-- <remote-command>]")
      yield* Effect.fail(new Error("Builder name is required"))
    }

    const builders = yield* BuildersService
    const ssh = yield* SshService

    const name = yield* builders.resolve(nameArg!)

    // Parse remote command from raw args if -- separator present
    const remoteCommand = parseRemoteCommand(parsed.raw, name)

    // Resolve builder's Tailscale IP
    const builderIP = yield* builders.resolveIP(name).pipe(
      Effect.catchTag("BuilderUnreachableError", (err) =>
        Effect.logError(`Failed to resolve ${name} via Tailscale: ${err.reason}`).pipe(
          Effect.andThen(Effect.fail(err))
        )
      )
    )

    // Scoped block: temp known_hosts file is auto-deleted when scope closes
    const exitCode = yield* Effect.scoped(
      Effect.gen(function* () {
        const knownHostsFile = yield* setupHostKeyVerification(builderIP)

        const sshOpts = {
          user: isRoot ? "root" : "remotebuild",
          port: 3098,
          identityFile: "/root/.ssh/builder-key",
          connectTimeout: 30,
          knownHostsFile
        }

        if (remoteCommand.length > 0) {
          // Non-interactive: run command and return output
          const result = yield* ssh.exec(builderIP, remoteCommand.join(" "), sshOpts).pipe(
            Effect.catchAll((sshError) =>
              Effect.logError(`SSH connection failed: ${String(sshError)}`).pipe(
                Effect.andThen(Effect.fail(sshError))
              )
            )
          )

          if (result.stdout) {
            process.stdout.write(result.stdout)
          }
          if (result.stderr) {
            process.stderr.write(result.stderr)
          }

          return result.exitCode
        } else {
          // Interactive: open SSH session
          return yield* ssh.interactive(builderIP, sshOpts).pipe(
            Effect.catchAll((sshError) =>
              Effect.logError(`SSH connection failed: ${String(sshError)}`).pipe(
                Effect.andThen(Effect.fail(sshError))
              )
            )
          )
        }
      })
    )

    process.exit(exitCode)
  })
