export interface ParsedStats {
  builds: number
  cpu_pct: number
  mem_pct: number
  idle_count: number
  ts_status: string
  ccache_mount: boolean
  ccache_sync: boolean
  transfers: number
}

export interface BuilderOutput {
  id: number
  name: string
  status: string
  public_net: { ipv4: { ip: string } }
  server_type: { name: string; description: string }
  created: string
  labels: Record<string, string>
  reachable: boolean
  builds?: number
  cpu_pct?: number
  mem_pct?: number
  idle_count?: number
  ts_status?: string
  ccache_mount?: boolean
  ccache_sync?: boolean
  transfers?: number
}
