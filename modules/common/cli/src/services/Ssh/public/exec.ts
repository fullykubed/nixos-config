import { Effect } from "effect"
import { ShellService } from "../../Shell"
import { SshConnectionError, SshAuthError, SshTimeoutError, SshHostKeyError } from "../errors"
import { type SshOpts } from "../types"
import { buildSshArgs } from "../internal/build-ssh-args"

/**
 * Execute a command on a remote host via SSH and capture its output.
 *
 * Runs in BatchMode (no interactive prompts).  The command string is
 * passed as a single argument to ssh, which hands it to the remote shell.
 */
export const exec = (host: string, command: string, opts?: SshOpts) =>
  Effect.gen(function* () {
    const shell = yield* ShellService
    const sshArgs = buildSshArgs(host, opts, { interactive: false })
    sshArgs.push(command)

    return yield* Effect.catchAll(
      shell.exec("ssh", sshArgs, {
        timeout: (opts?.connectTimeout ?? 30) * 1000
      }),
      (error) => {
        // Classify SSH failures by inspecting stderr patterns
        const stderr = "stderr" in error ? error.stderr : String(error)

        if (stderr.includes("Connection refused") || stderr.includes("No route to host")) {
          return Effect.fail(new SshConnectionError({
            host,
            exitCode: "exitCode" in error ? error.exitCode : -1,
            stderr
          }) as SshConnectionError | SshAuthError | SshTimeoutError | SshHostKeyError)
        }

        if (stderr.includes("Permission denied") || stderr.includes("Authentication failed")) {
          return Effect.fail(new SshAuthError({
            host,
            stderr
          }) as SshConnectionError | SshAuthError | SshTimeoutError | SshHostKeyError)
        }

        if (stderr.includes("timed out") || stderr.includes("Timeout")) {
          return Effect.fail(new SshTimeoutError({
            host,
            timeout: opts?.connectTimeout ?? 30
          }) as SshConnectionError | SshAuthError | SshTimeoutError | SshHostKeyError)
        }

        if (stderr.includes("Host key verification failed") ||
            stderr.includes("REMOTE HOST IDENTIFICATION HAS CHANGED")) {
          return Effect.fail(new SshHostKeyError({
            host,
            stderr
          }) as SshConnectionError | SshAuthError | SshTimeoutError | SshHostKeyError)
        }

        // Generic connection error for other cases
        return Effect.fail(new SshConnectionError({
          host,
          exitCode: "exitCode" in error ? error.exitCode : -1,
          stderr
        }) as SshConnectionError | SshAuthError | SshTimeoutError | SshHostKeyError)
      }
    )
  })