import { Effect } from "effect"
import type { SshService } from "../../../services/Ssh"

export const runSshCheck = (ip: string, ssh: SshService["Type"], command: string, timeout = 10) =>
  ssh.exec(ip, command, { connectTimeout: timeout, user: "remotebuild", port: 3098, identityFile: "/root/.ssh/builder-key" })
    .pipe(
      Effect.map(result => ({ stdout: result.stdout, stderr: result.stderr, exitCode: result.exitCode })),
      Effect.catchAll(error => {
        if (error._tag === "SshTimeoutError") {
          return Effect.succeed({ stdout: "", stderr: `SSH timeout after ${error.timeout}s`, exitCode: 1 })
        }
        return Effect.succeed({ stdout: "", stderr: error.stderr || `SSH error: ${error._tag}`, exitCode: 1 })
      })
    )
