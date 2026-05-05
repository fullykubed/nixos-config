import { Effect } from "effect"
import { HttpClient, HttpClientError, HttpClientRequest, HttpClientResponse } from "@effect/platform"
import { ServerId, ImageId, VolumeId, type Server, type Image, type Volume } from "./types"
import type { HcloudConfigShape } from "./config"

export const defaultHcloudConfig: HcloudConfigShape = {
  apiBaseUrl: "https://api.hetzner.cloud/v1",
  token: Effect.succeed("test-token"),
}

export const server1: Server = {
  id: ServerId(1),
  name: "builder-1",
  status: "running",
  public_net: { ipv4: { ip: "1.2.3.4" } },
  server_type: { name: "cpx62", description: "CPX 62" },
  created: "2024-01-01T00:00:00Z",
  labels: {},
}

export const server2: Server = {
  id: ServerId(2),
  name: "builder-2",
  status: "running",
  public_net: { ipv4: { ip: "5.6.7.8" } },
  server_type: { name: "cpx62", description: "CPX 62" },
  created: "2024-01-02T00:00:00Z",
  labels: { env: "test" },
}

export const image1: Image = {
  id: ImageId(100),
  name: "builder-snap-1",
  description: "Builder snapshot",
  type: "snapshot",
  status: "available",
  architecture: "x86",
  os_flavor: "unknown",
  os_version: null,
  rapid_deploy: false,
  created: "2024-01-01T00:00:00Z",
  created_from: { id: 1, name: "builder-1" },
  bound_to: null,
  deleted: null,
  deprecated: null,
  labels: { type: "builder" },
  protection: { delete: false },
}

export const image2: Image = {
  id: ImageId(101),
  name: "builder-snap-2",
  description: "Builder snapshot 2",
  type: "snapshot",
  status: "available",
  architecture: "x86",
  os_flavor: "unknown",
  os_version: null,
  rapid_deploy: false,
  created: "2024-01-02T00:00:00Z",
  created_from: { id: 2, name: "builder-2" },
  bound_to: null,
  deleted: null,
  deprecated: null,
  labels: { type: "builder" },
  protection: { delete: false },
}

export const volume1: Volume = {
  id: VolumeId(200),
  name: "ccache-builder-1",
  size: 50,
  location: {
    id: 1, name: "fsn1", description: "Falkenstein DC Park 1",
    country: "DE", city: "Falkenstein", latitude: 50.47612, longitude: 12.37044,
    network_zone: "eu-central",
  },
  labels: { "builder-ccache": "true" },
  linux_device: "/dev/sdb",
  protection: { delete: false },
  server: null,
  created: "2024-01-01T00:00:00Z",
}

export const volume2: Volume = {
  id: VolumeId(201),
  name: "ccache-builder-2",
  size: 50,
  location: {
    id: 1, name: "fsn1", description: "Falkenstein DC Park 1",
    country: "DE", city: "Falkenstein", latitude: 50.47612, longitude: 12.37044,
    network_zone: "eu-central",
  },
  labels: { "builder-ccache": "true" },
  linux_device: "/dev/sdc",
  protection: { delete: false },
  server: 2,
  created: "2024-01-02T00:00:00Z",
}

/** Create a mock HttpClient that returns responses in sequence. */
export const mockHttp = (...responses: Response[]) => {
  let i = 0
  return HttpClient.make((request) =>
    Effect.succeed(HttpClientResponse.fromWeb(request, responses[i++]!))
  )
}

/** Create a mock HttpClient that always fails with a transport error. */
export const failHttp = HttpClient.make((request) =>
  Effect.fail(new HttpClientError.RequestError({
    request,
    reason: "Transport",
    cause: new Error("Network error"),
  }))
)

/** Create a mock HttpClient that captures requests and returns responses in sequence. */
export const capturingHttp = (...responses: Response[]) => {
  let i = 0
  const requests: HttpClientRequest.HttpClientRequest[] = []
  const client = HttpClient.make((request) => {
    requests.push(request)
    return Effect.succeed(HttpClientResponse.fromWeb(request, responses[i++]!))
  })
  return { client, requests }
}