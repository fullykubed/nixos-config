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