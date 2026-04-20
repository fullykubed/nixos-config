import { Effect } from "effect"
import type { SshService } from "../../../services/Ssh"
import type { CheckResult } from "./handler"
import { runSshCheck } from "./run-ssh-check"

export const checkTailscaleStatus = (ip: string, ssh: SshService["Type"]): Effect.Effect<CheckResult> =>
  Effect.gen(function* () {
    const tsScript = `
      json=$(tailscale status --json 2>/dev/null) || { echo "error"; exit 0; }
      state=$(echo "$json" | jq -r ".BackendState // \\"unknown\\"")
      self_host=$(echo "$json" | jq -r ".Self.HostName // \\"unknown\\"")
      peer_count=$(echo "$json" | jq "[.Peer[] // empty] | length")
      echo "\${state}|\${self_host}|\${peer_count}"
    `

    const result = yield* runSshCheck(ip, ssh, tsScript)

    if (result.exitCode === 0) {
      const output = result.stdout.trim()
      if (output === "error") {
        return {
          name: "Tailscale status",
          status: "FAILED" as const,
          details: "tailscale status command failed"
        }
      }

      const [state, hostname, peers] = output.split('|')
      if (state === "Running") {
        return {
          name: "Tailscale status",
          status: "OK" as const,
          details: `up (hostname=${hostname ?? "?"}, ${peers ?? "?"} peers)`
        }
      } else {
        return {
          name: "Tailscale status",
          status: "WARNING" as const,
          details: `${state ?? "?"} (hostname=${hostname ?? "?"})`
        }
      }
    }

    return {
      name: "Tailscale status",
      status: "SKIPPED" as const,
      details: "SSH error",
      error: result.stderr
    }
  })
