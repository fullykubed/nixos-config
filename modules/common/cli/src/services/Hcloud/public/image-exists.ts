import { Effect } from "effect"
import type { ImageId } from "../types"
import { getImage } from "./get-image"

export const imageExists = (nameOrId: string | ImageId) =>
  getImage(nameOrId).pipe(
    Effect.map(() => true),
    Effect.catchTags({
      HcloudImageNotFound: () => Effect.succeed(false),
      HcloudGetImageError: () => Effect.succeed(false),
    })
  )
