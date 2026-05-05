import { Effect } from "effect"
import type { ServerId } from "../types"
import { getServer } from "./get-server"

export const serverExists = (nameOrId: string | ServerId) =>
  getServer(nameOrId).pipe(
    Effect.map(() => true),
    Effect.catchTags({
      HcloudServerNotFound: () => Effect.succeed(false),
      HcloudGetServerError: () => Effect.succeed(false),
    })
  )
