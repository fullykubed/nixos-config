import { type SshOpts } from "../types"

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