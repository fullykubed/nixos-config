import { Effect } from "effect"
import type { SshService } from "../../../services/Ssh"
import type { CheckResult } from "./handler"
import { runSshCheck } from "./run-ssh-check"

export const checkCcacheStatus = (ip: string, ssh: SshService["Type"]): Effect.Effect<CheckResult[]> =>
  Effect.gen(function* () {
    const checks: CheckResult[] = []

    // Check ccache volume mount
    const volScript = `
      svc=$(systemctl is-active builder-volume-mount.service 2>/dev/null || echo "inactive")
      dev=$(echo /dev/disk/by-id/scsi-0HC_Volume_*)
      if [ -b "$dev" ]; then
        attached="yes"
      else
        attached="no"
      fi
      if mountpoint -q /var/cache/ccache 2>/dev/null; then
        mounted="yes"
        df_line=$(df -h /var/cache/ccache --output=size,used,avail,pcent | tail -1)
        owner=$(stat -c "%U:%G" /var/cache/ccache 2>/dev/null || echo "unknown")
        perms=$(stat -c "%a" /var/cache/ccache 2>/dev/null || echo "unknown")
      else
        mounted="no"
        df_line=""
        owner=""
        perms=""
      fi
      printf "%s|%s|%s|%s|%s|%s" "$svc" "$attached" "$mounted" "$df_line" "$owner" "$perms"
    `

    const volResult = yield* runSshCheck(ip, ssh, volScript)
    if (volResult.exitCode === 0) {
      const [svc, attached, mounted, dfLine, owner, perms] = volResult.stdout.trim().split('|')
      if (mounted === "yes") {
        const [size, _used, avail] = dfLine!.split(/\s+/)
        checks.push({
          name: "ccache volume",
          status: "OK",
          details: `${avail ?? "?"} free / ${size ?? "?"} (${owner ?? "?"} ${perms ?? "?"})`
        })
      } else if (attached === "yes") {
        checks.push({
          name: "ccache volume",
          status: "FAILED",
          details: `volume attached but not mounted (service: ${svc ?? "unknown"})`
        })
      } else {
        checks.push({
          name: "ccache volume",
          status: "WARNING",
          details: `no volume attached (using R2-only ccache, service: ${svc ?? "unknown"})`
        })
      }
    } else {
      checks.push({
        name: "ccache volume",
        status: "SKIPPED",
        details: "SSH error",
        error: volResult.stderr
      })
    }

    // Check R2 upload timer
    const syncResult = yield* runSshCheck(ip, ssh, "systemctl is-active ccache-r2-upload.timer 2>/dev/null || echo inactive")
    if (syncResult.exitCode === 0) {
      const status = syncResult.stdout.trim()
      checks.push({
        name: "ccache R2 upload",
        status: status === "active" ? "OK" : "WARNING",
        details: status === "active" ? "timer active" : status
      })
    } else {
      checks.push({
        name: "ccache R2 upload",
        status: "SKIPPED",
        details: "SSH error",
        error: syncResult.stderr
      })
    }

    // Check ccache stats
    const statsScript = `
      if ! command -v ccache &>/dev/null; then echo "n/a"; exit 0; fi
      stats=$(ccache -d /var/cache/ccache --print-stats 2>/dev/null) || { echo "n/a"; exit 0; }
      dh=$(echo "$stats" | awk -F"\t" "/^direct_cache_hit/{print \\$2}")
      ph=$(echo "$stats" | awk -F"\t" "/^preprocessed_cache_hit/{print \\$2}")
      cm=$(echo "$stats" | awk -F"\t" "/^cache_miss/{print \\$2}")
      sz=$(echo "$stats" | awk -F"\t" "/^cache_size_kibibyte/{print \\$2}")
      dh=\${dh:-0}; ph=\${ph:-0}; cm=\${cm:-0}; sz=\${sz:-0}
      total=$((dh + ph + cm))
      if [ $total -gt 0 ]; then
        rate=$(( (dh + ph) * 100 / total ))
      else
        rate=0
      fi
      printf "%s|%s|%s" "$rate" "$((dh + ph))" "$sz"
    `

    const statsResult = yield* runSshCheck(ip, ssh, statsScript)
    if (statsResult.exitCode === 0) {
      const output = statsResult.stdout.trim()
      if (output === "n/a") {
        checks.push({
          name: "ccache stats",
          status: "WARNING",
          details: "ccache not available"
        })
      } else {
        const [hitRate, hitCount, sizeKb] = output.split('|')
        const sizeMb = Math.floor(parseInt(sizeKb!) / 1024)
        checks.push({
          name: "ccache stats",
          status: "OK",
          details: `${hitRate ?? "?"}% hit rate (${hitCount ?? "?"} hits), ${sizeMb} MB cache`
        })
      }
    } else {
      checks.push({
        name: "ccache stats",
        status: "SKIPPED",
        details: "SSH error",
        error: statsResult.stderr
      })
    }

    return checks
  })
