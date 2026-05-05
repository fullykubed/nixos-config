/** A single peer from the `tailscale status --json` Peer map. */
export interface TailscalePeer {
  HostName: string
  TailscaleIPs: string[]
  Online: boolean
}

/** Subset of `tailscale status --json` output relevant to this service. */
export interface TailscaleStatus {
  BackendState: string
  TUN: boolean
  Online: boolean
  TailscaleIPs: string[]
  Health: string[]
  Peer?: Record<string, TailscalePeer>
}