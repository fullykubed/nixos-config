import { Effect } from "effect"
import { SshConnectionError } from "../errors"
import { type SshOpts } from "../types"
import { buildSshArgs } from "../internal/build-ssh-args"

/**
 * Open an interactive SSH session with inherited stdio.
 *
 * Uses Bun.spawn directly (not ShellService) so that the terminal is
 * passed through.  Returns the SSH exit code; Ctrl+C (SIGINT / exit 130)
 * is treated as a normal exit rather than an error.
 */
export const interactive = (host: string, opts?: SshOpts) =>
  Effect.gen(function* () {
    const sshArgs = buildSshArgs(host, opts, { interactive: true })

    // Spawn SSH process with inherited stdio for interactive session
    const sshProcess = Bun.spawn(["ssh", ...sshArgs], {
      stdio: ["inherit", "inherit", "inherit"],
      env: process.env
    })

    const exitCode = yield* Effect.promise(() => sshProcess.exited)

    // Check exit code for SSH-specific errors
    if (exitCode !== 0) {
      // Since we inherit stdio, we don't have stderr captured
      // We'll need to infer the error type from the exit code
      if (exitCode === 255) {
        // SSH connection error (most common SSH failure exit code)
        yield* Effect.fail(new SshConnectionError({
          host,
          exitCode,
          stderr: "SSH connection failed (exit code 255)"
        }))
      }

      if (exitCode === 130) {
        // SIGINT (Ctrl+C) - not really an error, user interrupted
        return exitCode
      }

      // For other non-zero exit codes, treat as connection error
      yield* Effect.fail(new SshConnectionError({
        host,
        exitCode,
        stderr: `SSH process exited with code ${exitCode}`
      }))
    }

    return exitCode
  })