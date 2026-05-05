import { Context, Effect, Layer } from "effect"
import { HttpClient } from "@effect/platform"
import { HcloudConfig, loadHcloudConfig } from "./config"
import { mkContextInjector } from "../../lib/mkContextInjector"

// Re-export errors and types
export {
  HcloudServerNotFound,
  
  
  
  
  HcloudListServersError,
  
  HcloudCreateServerError,
  
  
  
  
  
  
  
} from "./errors"

export {
  ServerId,
  ImageId,
  VolumeId,
  type Server,
  type Image,
  type Volume,
  
  
} from "./types"

import { listServers } from "./public/list-servers"
import { getServer } from "./public/get-server"
import { serverExists } from "./public/server-exists"
import { createServer } from "./public/create-server"
import { deleteServer } from "./public/delete-server"
import { listImages } from "./public/list-images"
import { getImage } from "./public/get-image"
import { imageExists } from "./public/image-exists"
import { deleteImage } from "./public/delete-image"
import { listVolumes } from "./public/list-volumes"
import { getVolume } from "./public/get-volume"
import { volumeExists } from "./public/volume-exists"
import { createVolume } from "./public/create-volume"
import { deleteVolume } from "./public/delete-volume"
import { detachVolume } from "./public/detach-volume"

const make = Effect.gen(function* () {
  const config = yield* loadHcloudConfig
  const http = yield* HttpClient.HttpClient
  const ctx = Context.empty().pipe(
    Context.add(HcloudConfig, config),
    Context.add(HttpClient.HttpClient, http),
  )
  const inject = mkContextInjector(ctx, "Hcloud")

  return {
    listServers: inject(listServers),
    getServer: inject(getServer),
    serverExists: inject(serverExists),
    createServer: inject(createServer),
    deleteServer: inject(deleteServer),
    listImages: inject(listImages),
    getImage: inject(getImage),
    imageExists: inject(imageExists),
    deleteImage: inject(deleteImage),
    listVolumes: inject(listVolumes),
    getVolume: inject(getVolume),
    volumeExists: inject(volumeExists),
    createVolume: inject(createVolume),
    deleteVolume: inject(deleteVolume),
    detachVolume: inject(detachVolume),
  }
})

export type HcloudServiceShape = Effect.Effect.Success<typeof make>

export class HcloudService extends Context.Tag("HcloudService")<
  HcloudService,
  HcloudServiceShape
>() {}

export const HcloudLive = Layer.effect(HcloudService, make)
