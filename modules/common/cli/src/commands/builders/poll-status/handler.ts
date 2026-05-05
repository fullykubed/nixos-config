import { Effect, Option } from "effect"
import { FileSystem } from "@effect/platform"
import type { Parsed } from "./command"
import { BuildersService } from "../../../services/Builders"
import type { BuilderOutput } from "./types"

export const pollStatusHandler = (_parsed: Parsed) => Effect.gen(function* () {
  const fs = yield* FileSystem.FileSystem
  const builders = yield* BuildersService

  // 1. List builders
  const servers = yield* builders.list()

  // 2. Fetch stats from running builders in parallel
  const runningBuilders = servers.filter(s => s.status === "running")

  const statsResults = yield* Effect.all(
    runningBuilders.map(server =>
      builders.getStats(server.name).pipe(
        Effect.map(stats => ({ name: server.name, stats })),
        Effect.timeout("10 seconds"),
        Effect.catchAll(() => Effect.succeed({ name: server.name, stats: Option.none() }))
      )
    ),
    { concurrency: "unbounded" }
  )

  // 3. Merge hcloud + stats
  const merged: BuilderOutput[] = servers.map(server => {
    const statsEntry = statsResults.find(s => s.name === server.name)
    const baseOutput: BuilderOutput = {
      id: server.id,
      name: server.name,
      status: server.status,
      public_net: server.public_net,
      server_type: server.server_type,
      created: server.created,
      labels: server.labels,
      reachable: false
    }

    if (statsEntry?.stats && Option.isSome(statsEntry.stats)) {
      const s = statsEntry.stats.value
      return {
        ...baseOutput,
        reachable: true,
        builds: s.builds,
        cpu_pct: s.cpuPercent,
        mem_pct: s.memTotalKb > 0
          ? Math.round(s.memUsedKb * 100 / s.memTotalKb)
          : 0,
        idle_count: s.idleCount,
        ts_status: s.tailscaleStatus,
        ccache_mount: s.ccacheMount,
        ccache_sync: s.ccacheSync,
        transfers: s.serveCount
      }
    }

    return baseOutput
  })

  // 4. Atomic write
  const outputDir = "/run/builder-status"
  const outputFile = `${outputDir}/status.json`
  const tmpFile = `${outputFile}.tmp`

  yield* fs.makeDirectory(outputDir, { recursive: true }).pipe(
    Effect.catchAll(() => Effect.succeed(undefined))
  )
  yield* fs.writeFileString(tmpFile, JSON.stringify(merged, null, 2))
  yield* fs.rename(tmpFile, outputFile)

  // Log summary to stderr (journalctl)
  const reachable = merged.filter(m => m.reachable).length
  yield* Effect.log(`:: wrote status.json (${reachable} reachable / ${servers.length} total builders)`)
})
