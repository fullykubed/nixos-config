import { Effect } from "effect"
import type { Parsed } from "./command"
import { BuildersService } from "../../../services/Builders"
import { SshService } from "../../../services/Ssh"
import { ShellService } from "../../../services/Shell"
import { json } from "../../../lib/output"
import { colorize } from "./colorize"
import { checkSshConnectivity } from "./check-ssh"
import { checkNixVersion } from "./check-nix"
import { checkHardwareInfo } from "./check-hardware"
import { checkCpuPerformance } from "./check-cpu"
import { checkNetworkPerformance } from "./check-network"
import { checkDiskPerformance } from "./check-disk"
import { checkTailscaleStatus } from "./check-tailscale"
import { checkCcacheStatus } from "./check-ccache"
import { checkShutdownStatus } from "./check-shutdown"

export interface CheckResult {
  name: string
  status: "OK" | "FAILED" | "SKIPPED" | "WARNING"
  details: string
  error?: string
}

interface CheckOutput {
  builderName: string
  tailscaleIP?: string
  connectivity: "OK" | "FAILED"
  checks: CheckResult[]
}

export const checkHandler = (parsed: Parsed) => Effect.gen(function* () {
  const builders = yield* BuildersService
  const ssh = yield* SshService
  const shell = yield* ShellService

  const name = yield* builders.resolve(parsed.args.name)

  // Check if any specific flags are set
  const hasSpecificFlags = [
    "nix", "hw", "cpu", "net", "disk", "tailscale", "ccache", "shutdown"
  ].some(flag => (parsed.flags as Record<string, boolean>)[flag] === true)

  const shouldRun = (checkName: string) =>
    !hasSpecificFlags || (parsed.flags as Record<string, boolean>)[checkName] === true

  yield* Effect.log(`Checking ${name}...`)

  // Verify server exists in Hetzner
  yield* builders.get(name).pipe(
    Effect.catchTag("BuilderNotFoundError", () =>
      Effect.logError(`Builder ${name} does not exist`).pipe(
        Effect.andThen(Effect.fail("Builder not found"))
      )
    )
  )

  // Get Tailscale IP
  const ip = yield* builders.resolveIP(name).pipe(
    Effect.catchTag("BuilderUnreachableError", (err) =>
      Effect.logError(`Builder ${name} not found in Tailscale network: ${err.reason}`).pipe(
        Effect.andThen(Effect.logError("The builder may still be booting or Tailscale may not have connected yet.")),
        Effect.andThen(Effect.fail("Tailscale resolution failed"))
      )
    )
  )

  yield* Effect.log(`Tailscale IP: ${ip}`)

  const output: CheckOutput = {
    builderName: name,
    tailscaleIP: ip,
    connectivity: "FAILED",
    checks: []
  }

  // Check SSH connectivity first (always run)
  const connectivityResult = yield* checkSshConnectivity(ip, ssh)
  output.connectivity = connectivityResult.status === "OK" ? "OK" : "FAILED"

  if (connectivityResult.status === "FAILED") {
    if (parsed.flags.json) {
      json(output)
      return
    }

    yield* Effect.log(`SSH connectivity: ${colorize("FAILED", "FAILED")}`)
    if (connectivityResult.error) {
      yield* Effect.log(`  Error: ${connectivityResult.error}`)
    }
    yield* Effect.log("  The builder may not be fully booted or SSH may not be ready yet.")
    return
  }

  yield* Effect.log(`SSH connectivity: ${colorize("OK", "OK")}`)

  // Run individual checks
  const allChecks: CheckResult[] = []

  if (shouldRun("nix")) {
    const result = yield* checkNixVersion(ip, ssh)
    allChecks.push(result)
  }

  if (shouldRun("hw")) {
    const result = yield* checkHardwareInfo(ip, ssh)
    allChecks.push(result)
  }

  if (shouldRun("cpu")) {
    yield* Effect.log("Running CPU benchmark (30s)...")
    const result = yield* checkCpuPerformance(ip, ssh)
    allChecks.push(result)
  }

  if (shouldRun("net")) {
    const result = yield* checkNetworkPerformance(ip, ssh, shell)
    allChecks.push(result)
  }

  if (shouldRun("disk")) {
    yield* Effect.log("Running disk benchmark (30s)...")
    const result = yield* checkDiskPerformance(ip, ssh)
    allChecks.push(result)
  }

  if (shouldRun("tailscale")) {
    const result = yield* checkTailscaleStatus(ip, ssh)
    allChecks.push(result)
  }

  if (shouldRun("ccache")) {
    const results = yield* checkCcacheStatus(ip, ssh)
    allChecks.push(...results)
  }

  if (shouldRun("shutdown")) {
    const result = yield* checkShutdownStatus(ip, ssh)
    allChecks.push(result)
  }

  output.checks = allChecks

  // Output results
  if (parsed.flags.json) {
    json(output)
    return
  }

  // Human-readable output
  for (const check of allChecks) {
    const statusText = colorize(check.status, check.status)
    yield* Effect.log(`${check.name}: ${statusText}${check.details ? ` - ${check.details}` : ""}`)
    if (check.error) {
      yield* Effect.log(`  Error: ${check.error}`)
    }
  }

  // Summary
  const failedChecks = allChecks.filter(c => c.status === "FAILED")
  const warningChecks = allChecks.filter(c => c.status === "WARNING")

  if (failedChecks.length === 0 && warningChecks.length === 0) {
    yield* Effect.log(`Builder ${name} is healthy`)
  } else if (failedChecks.length === 0) {
    yield* Effect.logWarning(`Builder ${name} is healthy with warnings`)
  } else {
    yield* Effect.logError(`Builder ${name} has ${failedChecks.length} failed check${failedChecks.length > 1 ? "s" : ""}`)
  }
})
