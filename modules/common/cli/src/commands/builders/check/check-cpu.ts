import { Effect } from "effect"
import type { SshService } from "../../../services/Ssh"
import type { CheckResult } from "./handler"
import { runSshCheck } from "./run-ssh-check"

export const checkCpuPerformance = (ip: string, ssh: SshService["Type"]): Effect.Effect<CheckResult> =>
  Effect.gen(function* () {
    const benchScript = `
      cores=$(nproc)

      # Single-core SHA256 for ~15s
      s=$(date +%s%N)
      deadline=$(( $(date +%s) + 15 ))
      total=0
      while [ $(date +%s) -lt $deadline ]; do
        dd if=/dev/zero bs=1M count=256 2>/dev/null | sha256sum >/dev/null
        total=$((total + 256))
      done
      e=$(date +%s%N)
      elapsed_ms=$(( (e - s) / 1000000 ))
      if [ $elapsed_ms -gt 0 ]; then hash_mbs=$((total * 1000 / elapsed_ms)); else hash_mbs=0; fi

      # All-core xz for ~15s
      s=$(date +%s%N)
      deadline=$(( $(date +%s) + 15 ))
      total=0
      while [ $(date +%s) -lt $deadline ]; do
        dd if=/dev/zero bs=1M count=32 2>/dev/null | xz -T0 -6 >/dev/null
        total=$((total + 32))
      done
      e=$(date +%s%N)
      elapsed_ms=$(( (e - s) / 1000000 ))
      if [ $elapsed_ms -gt 0 ]; then xz_mbs=$((total * 1000 / elapsed_ms)); else xz_mbs=0; fi

      printf "%s|%s|%s" "$hash_mbs" "$xz_mbs" "$cores"
    `

    const result = yield* runSshCheck(ip, ssh, benchScript, 45)

    if (result.exitCode === 0) {
      const [hashMbs, xzMbs, cores] = result.stdout.trim().split('|')
      return {
        name: "CPU performance",
        status: "OK" as const,
        details: `SHA256: ${hashMbs ?? "?"} MB/s (1 core) | xz -6: ${xzMbs ?? "?"} MB/s (${cores ?? "?"} cores)`
      }
    }

    return {
      name: "CPU performance",
      status: "SKIPPED" as const,
      details: "Benchmark failed",
      error: result.stderr
    }
  })
