import { Context, Data, Effect, Layer } from "effect"
import { ShellService } from "./Shell"

/**
 * SSH execution service for remote builder VMs.
 *
 * Provides two modes of SSH interaction:
 *
 *   exec        – run a command on a remote host and capture its output
 *   interactive – open a full interactive SSH session (stdio inherited)
 *
 * All connections default to port 3098 as the "remotebuild" user with the
 * builder identity key at /root/.ssh/builder-key.  Host key verification is
 * always strict; callers must supply a knownHostsFile when the builder's
 * host key isn't in the system known_hosts.
 *
 * SSH config files are intentionally bypassed (-F /dev/null) so that user
 * or system ssh_config stanzas cannot interfere with builder connections.
 *
 * Error classification:  The service inspects stderr to distinguish four
 * failure modes (connection refused, auth failure, timeout, host key
 * mismatch), each with its own tagged error type for precise catch handling
 * by callers.
 */

/** Per-connection options.  All fields are optional and have sensible defaults for builders. */
export interface SshOpts {
  /** Remote username (default: "remotebuild"). */
  readonly user?: string
  /** SSH port (default: 3098). */
  readonly port?: number
  /** Path to the private key file (default: "/root/.ssh/builder-key"). */
  readonly identityFile?: string
  /** TCP connect timeout in seconds (default: 30). Also used as the ShellService exec timeout. */
  readonly connectTimeout?: number
  /** Path to a temporary known_hosts file for host key verification. */
  readonly knownHostsFile?: string
}

/** TCP connection could not be established (refused, no route, generic failure). */
export class SshConnectionError extends Data.TaggedError("SshConnectionError")<{
  readonly host: string
  readonly exitCode: number
  readonly stderr: string
}> {}

/** Authentication was rejected by the remote host (wrong key, permission denied). */
export class SshAuthError extends Data.TaggedError("SshAuthError")<{
  readonly host: string
  readonly stderr: string
}> {}

/** The SSH connection timed out before the handshake completed. */
export class SshTimeoutError extends Data.TaggedError("SshTimeoutError")<{
  readonly host: string
  readonly timeout: number
}> {}

/** The remote host key didn't match the expected key in known_hosts. */
export class SshHostKeyError extends Data.TaggedError("SshHostKeyError")<{
  readonly host: string
  readonly stderr: string
}> {}

export interface SshServiceShape {
  /**
   * Execute a command on a remote host via SSH and capture its output.
   *
   * Runs in BatchMode (no interactive prompts).  The command string is
   * passed as a single argument to ssh, which hands it to the remote shell.
   */
  exec(host: string, command: string, opts?: SshOpts): Effect.Effect<
    { stdout: string; stderr: string; exitCode: number },
    SshConnectionError | SshAuthError | SshTimeoutError | SshHostKeyError
  >

  /**
   * Open an interactive SSH session with inherited stdio.
   *
   * Uses Bun.spawn directly (not ShellService) so that the terminal is
   * passed through.  Returns the SSH exit code; Ctrl+C (SIGINT / exit 130)
   * is treated as a normal exit rather than an error.
   */
  interactive(host: string, opts?: SshOpts): Effect.Effect<
    number,
    SshConnectionError | SshAuthError | SshTimeoutError | SshHostKeyError
  >
}

export class SshService extends Context.Tag("SshService")<
  SshService,
  SshServiceShape
>() {}

const makeSshService = (shell: ShellService["Type"]): SshServiceShape => ({
  exec: (host: string, command: string, opts?: SshOpts) => Effect.gen(function* () {
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
  }),

  interactive: (host: string, opts?: SshOpts) => Effect.gen(function* () {
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
})

/**
 * Build the ssh argument vector from SshOpts.
 *
 * Key decisions:
 *  - `-F /dev/null` ignores all ssh_config files so user stanzas (ProxyCommand,
 *    Match exec, etc.) don't fire and interfere with direct builder connections.
 *  - `StrictHostKeyChecking=yes` is always on; callers that need a custom host
 *    key supply a temporary known_hosts via opts.knownHostsFile.
 *  - `BatchMode=yes` is set for non-interactive exec to prevent password prompts
 *    or other interactive queries from hanging the process.
 */
export function buildSshArgs(host: string, opts?: SshOpts, execOpts?: { interactive: boolean }): string[] {
  const args: string[] = []

  args.push("-F", "/dev/null")

  args.push("-p", String(opts?.port ?? 3098))
  args.push("-i", opts?.identityFile ?? "/root/.ssh/builder-key")
  args.push("-o", "IdentitiesOnly=yes")

  args.push("-o", "StrictHostKeyChecking=yes")
  if (opts?.knownHostsFile) {
    args.push("-o", `UserKnownHostsFile=${opts.knownHostsFile}`)
  }

  if (opts?.connectTimeout) {
    args.push("-o", `ConnectTimeout=${opts.connectTimeout}`)
  }

  if (!execOpts?.interactive) {
    args.push("-o", "BatchMode=yes")
  }

  const user = opts?.user ?? "remotebuild"
  args.push(`${user}@${host}`)

  return args
}

export const SshLive = Layer.effect(
  SshService,
  Effect.gen(function* () {
    const shell = yield* ShellService
    return makeSshService(shell)
  })
)