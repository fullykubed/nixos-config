import { Effect } from "effect"
import { FileSystem } from "@effect/platform"

/**
 * Setup SSH host key verification using builder host key.
 * Returns the path to a scoped temp known_hosts file (auto-deleted on scope close).
 */
export const setupHostKeyVerification = (ip: string) =>
  Effect.gen(function* () {
    const fs = yield* FileSystem.FileSystem
    const hostPubkeyFile = "/etc/ssh/builder-host-key.pub"

    // Read the builder host public key
    const hostPubkey = yield* fs.readFileString(hostPubkeyFile)

    // Create scoped temporary known_hosts file (auto-cleaned on scope close)
    const knownHostsFile = yield* fs.makeTempFileScoped({ directory: "/tmp", prefix: "ssh-known-hosts-" })
    yield* fs.writeFileString(knownHostsFile, `${ip} ${hostPubkey.trim()}\n`)

    return knownHostsFile
  })
