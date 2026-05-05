/**
 * Builder-specific types for the builders command group.
 * Extends the base Hcloud Server type with builder-specific information.
 */

import type { Server } from "../../services/Hcloud"

export interface Builder {
  readonly name: string
  readonly status: Server["status"]
  readonly serverType: string
  readonly publicIp: string
  readonly created: string
}
