import { Data } from "effect"

export class HcloudTokenError extends Data.TaggedError("HcloudTokenError")<{
  readonly message: string
  readonly cause?: unknown
}> {}

export class HcloudServerNotFound extends Data.TaggedError("HcloudServerNotFound")<{
  readonly name: string
  readonly cause?: unknown
}> {}

export class HcloudImageNotFound extends Data.TaggedError("HcloudImageNotFound")<{
  readonly id: string | number
  readonly cause?: unknown
}> {}

export class HcloudVolumeNotFound extends Data.TaggedError("HcloudVolumeNotFound")<{
  readonly name: string
  readonly cause?: unknown
}> {}

export class HcloudGetImageError extends Data.TaggedError("HcloudGetImageError")<{
  readonly id: string | number
  readonly message: string
  readonly cause?: unknown
}> {}

export class HcloudGetVolumeError extends Data.TaggedError("HcloudGetVolumeError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

export class HcloudListServersError extends Data.TaggedError("HcloudListServersError")<{
  readonly message: string
  readonly cause?: unknown
}> {}

export class HcloudGetServerError extends Data.TaggedError("HcloudGetServerError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

export class HcloudCreateServerError extends Data.TaggedError("HcloudCreateServerError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

export class HcloudDeleteServerError extends Data.TaggedError("HcloudDeleteServerError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

export class HcloudListImagesError extends Data.TaggedError("HcloudListImagesError")<{
  readonly message: string
  readonly cause?: unknown
}> {}

export class HcloudDeleteImageError extends Data.TaggedError("HcloudDeleteImageError")<{
  readonly id: string | number
  readonly message: string
  readonly cause?: unknown
}> {}

export class HcloudListVolumesError extends Data.TaggedError("HcloudListVolumesError")<{
  readonly message: string
  readonly cause?: unknown
}> {}

export class HcloudCreateVolumeError extends Data.TaggedError("HcloudCreateVolumeError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

export class HcloudDeleteVolumeError extends Data.TaggedError("HcloudDeleteVolumeError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}

export class HcloudDetachVolumeError extends Data.TaggedError("HcloudDetachVolumeError")<{
  readonly name: string
  readonly message: string
  readonly cause?: unknown
}> {}