import { Brand } from "effect"

export type ServerId = number & Brand.Brand<"ServerId">
export const ServerId = Brand.nominal<ServerId>()

export type ImageId = number & Brand.Brand<"ImageId">
export const ImageId = Brand.nominal<ImageId>()

export type VolumeId = number & Brand.Brand<"VolumeId">
export const VolumeId = Brand.nominal<VolumeId>()

export interface Server {
  readonly id: ServerId
  readonly name: string
  readonly status: "running" | "starting" | "stopping" | "off" | "deleting" | "migrating" | "rebuilding" | "unknown"
  readonly public_net: { readonly ipv4: { readonly ip: string } }
  readonly server_type: { readonly name: string; readonly description: string }
  readonly created: string
  readonly labels: Record<string, string>
}

export interface Image {
  readonly id: ImageId
  readonly name: string | null
  readonly description: string | null
  readonly type: "system" | "snapshot" | "backup" | "app"
  readonly status: "available" | "creating"
  readonly architecture: "x86" | "arm"
  readonly os_flavor: string
  readonly os_version: string | null
  readonly rapid_deploy: boolean
  readonly created: string
  readonly created_from: {
    readonly id: number
    readonly name: string
  } | null
  readonly bound_to: number | null
  readonly deleted: string | null
  readonly deprecated: string | null
  readonly labels: Record<string, string>
  readonly protection: {
    readonly delete: boolean
  }
}

export interface Volume {
  readonly id: VolumeId
  readonly name: string
  readonly size: number
  readonly location: {
    readonly id: number
    readonly name: string
    readonly description: string
    readonly country: string
    readonly city: string
    readonly latitude: number
    readonly longitude: number
    readonly network_zone: string
  }
  readonly labels: Record<string, string>
  readonly linux_device: string | null
  readonly protection: {
    readonly delete: boolean
  }
  readonly server: number | null
  readonly created: string
}

export interface CreateServerOptions {
  readonly name: string
  readonly type: string
  readonly location: string
  readonly image: string | number
  readonly sshKeys?: readonly string[]
  readonly userData?: string
  readonly volumes?: readonly number[]
  readonly labels?: Record<string, string>
  readonly waitForRunning?: boolean
}

export interface CreateVolumeOptions {
  readonly name: string
  readonly size: number
  readonly location: string
  readonly labels?: Record<string, string>
  readonly format?: string
}