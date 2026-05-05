import { Effect, Option } from "effect"
import { BuildersService, type BuilderStats } from "../../../services/Builders"

// Fetch all builder stats in parallel
export function fetchAllBuilderStats() {
  return Effect.gen(function* () {
    const builders = yield* BuildersService

    const servers = yield* builders.list().pipe(
      Effect.catchAll(() => Effect.succeed([]))
    )

    const runningServers = servers.filter(s => s.status === "running")

    if (runningServers.length === 0) {
      return [] as BuilderStats[]
    }

    // Fetch stats from each running builder in parallel
    const statsEffects = runningServers.map(server =>
      builders.getStats(server.name)
    )

    const results = yield* Effect.all(statsEffects, { concurrency: "unbounded" }).pipe(
      Effect.catchAll(() => Effect.succeed([] as Option.Option<BuilderStats>[]))
    )

    return results.flatMap(Option.toArray)
  })
}
