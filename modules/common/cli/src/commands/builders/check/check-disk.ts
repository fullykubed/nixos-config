import { Effect } from "effect"
import type { SshService } from "../../../services/Ssh"
import type { CheckResult } from "./handler"
import { runSshCheck } from "./run-ssh-check"

export const checkDiskPerformance = (ip: string, ssh: SshService["Type"]): Effect.Effect<CheckResult> =>
  Effect.gen(function* () {
    // First check disk space
    const spaceResult = yield* runSshCheck(ip, ssh, "df -h /nix/store --output=size,used,avail,pcent | tail -1")

    let spaceInfo = ""
    if (spaceResult.exitCode === 0) {
      const [size, _used, avail, pct] = spaceResult.stdout.trim().split(/\s+/)
      spaceInfo = `${avail ?? "?"} available / ${size ?? "?"} total (${pct ?? "?"} used)`
    }

    // Run fio benchmark
    const fioScript = `
      fio --name=test --ioengine=libaio --direct=1 --bs=4k --size=256M \\
          --rw=randrw --rwmixread=70 --iodepth=32 --runtime=30 --time_based \\
          --filename=/tmp/fio-test --output-format=json --group_reporting 2>/dev/null && rm -f /tmp/fio-test
    `

    const fioResult = yield* runSshCheck(ip, ssh, fioScript, 45)

    if (fioResult.exitCode === 0 && fioResult.stdout.trim()) {
      const parsed = yield* Effect.try({
        try: () => JSON.parse(fioResult.stdout) as { jobs?: { read?: { iops?: number; bw?: number }; write?: { iops?: number; bw?: number } }[] },
        catch: () => null,
      }).pipe(Effect.catchAll(() => Effect.succeed(null)))

      const job = parsed?.jobs?.[0]
      if (job) {
        const readIops = Math.floor(job.read?.iops ?? 0)
        const readBwMb = ((job.read?.bw ?? 0) / 1024).toFixed(1)
        const writeIops = Math.floor(job.write?.iops ?? 0)
        const writeBwMb = ((job.write?.bw ?? 0) / 1024).toFixed(1)

        let details = `read: ${readIops} IOPS ${readBwMb} MB/s | write: ${writeIops} IOPS ${writeBwMb} MB/s (4K randrw 70/30)`
        if (spaceInfo) {
          details += ` | ${spaceInfo}`
        }

        return {
          name: "Disk performance",
          status: "OK" as const,
          details
        }
      }
    }

    return {
      name: "Disk performance",
      status: "SKIPPED" as const,
      details: spaceInfo || "Disk benchmark failed",
      error: fioResult.stderr
    }
  })
