import { Effect } from "effect"
import type { SshService } from "../../../services/Ssh"
import type { CheckResult } from "./handler"
import { runSshCheck } from "./run-ssh-check"

export const checkSshConnectivity = (ip: string, ssh: SshService["Type"]): Effect.Effect<CheckResult> =>
  Effect.gen(function* () {
    const result = yield* runSshCheck(ip, ssh, "true", 10)

    if (result.exitCode === 0) {
      return {
        name: "SSH connectivity",
        status: "OK" as const,
        details: ""
      }
    }

    return {
      name: "SSH connectivity",
      status: "FAILED" as const,
      details: "Connection failed",
      error: result.stderr
    }
  })
