import type { BuilderStats } from "./Builders"

// Parse the 20-field pipe-delimited output into BuilderStats
export function parseStats(name: string, output: string): BuilderStats {
  const parts = output.trim().split('|')

  if (parts.length !== 20) {
    throw new Error(`Expected 20 fields, got ${parts.length}`)
  }

  return {
    name,
    reachable: true,
    builds: parseInt(parts[0]!, 10) || 0,
    cpuPercent: parseInt(parts[1]!, 10) || 0,
    memUsedKb: parseInt(parts[2]!, 10) || 0,
    memTotalKb: parseInt(parts[3]!, 10) || 0,
    diskReadSectors: parseInt(parts[4]!, 10) || 0,
    diskWriteSectors: parseInt(parts[5]!, 10) || 0,
    diskTotalKb: parseInt(parts[6]!, 10) || 0,
    diskUsedKb: parseInt(parts[7]!, 10) || 0,
    diskPercent: parseInt(parts[8]!, 10) || 0,
    sshSessions: parseInt(parts[9]!, 10) || 0,
    tailscaleStatus: parts[10]! || "unknown",
    queuePending: parseInt(parts[11]!, 10) || 0,
    queueDone: parseInt(parts[12]!, 10) || 0,
    idleCount: parseInt(parts[13]!, 10) || 0,
    ccacheHits: parseInt(parts[14]!, 10) || 0,
    ccacheMisses: parseInt(parts[15]!, 10) || 0,
    ccacheSizeKb: parseInt(parts[16]!, 10) || 0,
    ccacheMount: (parts[17] ?? "") === "1",
    ccacheSync: (parts[18] ?? "") === "1",
    serveCount: parseInt(parts[19]!, 10) || 0,
    uptimeHours: 0
  }
}
