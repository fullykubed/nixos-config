import { Effect } from "effect"
import type { VolumeId } from "../types"
import { getVolume } from "./get-volume"

export const volumeExists = (nameOrId: string | VolumeId) =>
  getVolume(nameOrId).pipe(
    Effect.map(() => true),
    Effect.catchTags({
      HcloudVolumeNotFound: () => Effect.succeed(false),
      HcloudGetVolumeError: () => Effect.succeed(false),
    })
  )
