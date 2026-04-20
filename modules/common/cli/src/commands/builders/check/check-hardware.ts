import { Effect } from "effect"
import type { SshService } from "../../../services/Ssh"
import type { CheckResult } from "./handler"
import { runSshCheck } from "./run-ssh-check"

export const checkHardwareInfo = (ip: string, ssh: SshService["Type"]): Effect.Effect<CheckResult> =>
  Effect.gen(function* () {
    const hwScript = `
      cores=$(nproc)
      model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
      kb=$(awk "/^MemTotal:/{print \\$2}" /proc/meminfo)
      gb_w=$((kb / 1048576)); gb_f=$(( (kb % 1048576) * 10 / 1048576 ))
      printf "%s|%s|%s.%s" "$cores" "$model" "$gb_w" "$gb_f"
    `

    const result = yield* runSshCheck(ip, ssh, hwScript)

    if (result.exitCode === 0) {
      const [cores, model, memory] = result.stdout.trim().split('|')
      return {
        name: "Hardware info",
        status: "OK" as const,
        details: `${cores ?? "?"}x ${model ?? "?"}, ${memory ?? "?"} GB RAM`
      }
    }

    return {
      name: "Hardware info",
      status: "SKIPPED" as const,
      details: "Could not get hardware info",
      error: result.stderr
    }
  })
