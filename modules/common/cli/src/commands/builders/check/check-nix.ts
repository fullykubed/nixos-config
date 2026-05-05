import { Effect } from "effect"
import type { SshService } from "../../../services/Ssh"

import { runSshCheck } from "./run-ssh-check"

export const checkNixVersion = (ip: string, ssh: SshService["Type"]) =>
  Effect.gen(function* () {
    const result = yield* runSshCheck(ip, ssh, "nix --version")

    if (result.exitCode === 0) {
      const version = result.stdout.trim()

      // Also check experimental features
      const expResult = yield* runSshCheck(ip, ssh, "nix config show experimental-features 2>/dev/null || nix show-config 2>/dev/null | grep '^experimental-features' | cut -d= -f2 | xargs")

      let details = version
      if (expResult.exitCode === 0 && expResult.stdout.trim()) {
        details += ` (features: ${expResult.stdout.trim()})`
      } else {
        details += " (features: none)"
      }

      return {
        name: "Nix version",
        status: "OK" as const,
        details
      }
    }

    return {
      name: "Nix version",
      status: "FAILED" as const,
      details: "Could not get Nix version",
      error: result.stderr
    }
  })
