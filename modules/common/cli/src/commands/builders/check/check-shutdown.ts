import { Effect } from "effect"
import type { SshService } from "../../../services/Ssh"
import type { CheckResult } from "./handler"
import { runSshCheck } from "./run-ssh-check"

export const checkShutdownStatus = (ip: string, ssh: SshService["Type"]): Effect.Effect<CheckResult> =>
  Effect.gen(function* () {
    const shutdownScript = `
      timer=$(systemctl is-active inactivity-monitor.timer 2>/dev/null || echo inactive)
      idle=$(cat /var/lib/inactivity-monitor/idle-count 2>/dev/null || echo 0)
      active=0
      ps -eo user= 2>/dev/null | sort -u | grep -q "^nixbld" && active=1
      printf "%s|%s|%s" "$timer" "$idle" "$active"
    `

    const result = yield* runSshCheck(ip, ssh, shutdownScript)

    if (result.exitCode === 0) {
      const [timerState, idleCountStr, isActiveStr] = result.stdout.trim().split('|')
      const idleCount = parseInt(idleCountStr!) || 0
      const isActive = isActiveStr === "1"

      if (timerState !== "active") {
        return {
          name: "Auto-shutdown",
          status: "WARNING" as const,
          details: "timer not running"
        }
      } else if (isActive) {
        return {
          name: "Auto-shutdown",
          status: "OK" as const,
          details: "idle counter reset (builder active)"
        }
      } else {
        const remaining = 15 - idleCount
        let status: CheckResult["status"] = "OK"
        if (remaining <= 2) {
          status = "FAILED"
        } else if (remaining <= 5) {
          status = "WARNING"
        }

        return {
          name: "Auto-shutdown",
          status,
          details: `~${remaining} min remaining (idle ${idleCount}/15 min)`
        }
      }
    }

    return {
      name: "Auto-shutdown",
      status: "SKIPPED" as const,
      details: "SSH error",
      error: result.stderr
    }
  })
