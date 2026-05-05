export type { Server } from "../Hcloud"

/** Runtime stats collected from a builder via SSH. */
export interface BuilderStats {
  name: string
  reachable: boolean
  builds: number
  cpuPercent: number
  memUsedKb: number
  memTotalKb: number
  diskReadSectors: number
  diskWriteSectors: number
  diskTotalKb: number
  diskUsedKb: number
  diskPercent: number
  sshSessions: number
  tailscaleStatus: string
  queuePending: number
  queueDone: number
  idleCount: number
  ccacheHits: number
  ccacheMisses: number
  ccacheSizeKb: number
  ccacheMount: boolean
  ccacheSync: boolean
  serveCount: number
  uptimeHours: number
  error?: string
}
