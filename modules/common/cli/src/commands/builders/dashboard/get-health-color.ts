import type { BuilderStats } from "./types"

export type HealthColor = "red" | "yellow" | "green"

export function getHealthColor(stats: BuilderStats): HealthColor {
  if (!stats.reachable) return "red"
  if (stats.cpuPercent > 80 || (stats.memTotalKb > 0 && (stats.memUsedKb / stats.memTotalKb) > 0.9)) {
    return "yellow"
  }
  if (!stats.ccacheMount || !stats.ccacheSync) return "yellow"
  return "green"
}
