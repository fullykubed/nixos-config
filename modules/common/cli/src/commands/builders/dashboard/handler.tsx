/* eslint-disable @typescript-eslint/no-unsafe-return -- OpenTUI JSX types resolve to any */
import { Effect, Layer } from "effect"
import { render } from "@opentui/solid"
import type { ParsedCommand } from "../../../cli/types"
import { BuildersService } from "../../../services/Builders"
import { fetchAllBuilderStats } from "./fetch-all-stats"
import { Dashboard } from "./render"

export const dashboardHandler = (_parsed: ParsedCommand) =>
  Effect.gen(function* () {
    const builders = yield* BuildersService

    const serviceLayer = Layer.succeed(BuildersService, builders)

    const fetchStats = () =>
      Effect.runPromise(
        fetchAllBuilderStats().pipe(
          Effect.provide(serviceLayer),
          Effect.catchAll(() => Effect.succeed([]))
        )
      )

    // render() resolves immediately after mounting — it does NOT wait for
    // the renderer to be destroyed. Wrap it so the Effect stays alive until
    // the user quits ('q' or Ctrl+C triggers renderer.destroy → onDestroy).
    yield* Effect.promise(() =>
      new Promise<void>((resolve) => {
        void render(() => <Dashboard fetchStats={fetchStats} />, {
          exitOnCtrlC: true,
          screenMode: "alternate-screen",
          useMouse: false,
          onDestroy: () => { resolve() },
        })
      })
    )
  })
