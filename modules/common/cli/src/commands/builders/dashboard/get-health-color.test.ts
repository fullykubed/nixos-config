import { describe, it, expect } from "bun:test"
import { getHealthColor } from "./get-health-color"
import type { BuilderStats } from "./types"

const makeStats = (overrides: Partial<BuilderStats> = {}): BuilderStats => ({
  name: "builder-1",
  reachable: true,
  builds: 0,
  cpuPercent: 10,
  memUsedKb: 1000,
  memTotalKb: 10000,
  diskReadSectors: 0,
  diskWriteSectors: 0,
  diskTotalKb: 100000,
  diskUsedKb: 50000,
  diskPercent: 50,
  sshSessions: 0,
  tailscaleStatus: "running",
  queuePending: 0,
  queueDone: 0,
  idleCount: 0,
  ccacheHits: 0,
  ccacheMisses: 0,
  ccacheSizeKb: 0,
  ccacheMount: true,
  ccacheSync: true,
  serveCount: 0,
  uptimeHours: 1,
  ...overrides,
})

describe("getHealthColor", () => {
  it("returns red when unreachable", () => {
    expect(getHealthColor(makeStats({ reachable: false }))).toBe("red")
  })

  it("returns yellow when CPU is high (>80%)", () => {
    expect(getHealthColor(makeStats({ cpuPercent: 81 }))).toBe("yellow")
    expect(getHealthColor(makeStats({ cpuPercent: 100 }))).toBe("yellow")
  })

  it("returns yellow when memory usage is high (>90%)", () => {
    expect(getHealthColor(makeStats({ memUsedKb: 9100, memTotalKb: 10000 }))).toBe("yellow")
  })

  it("returns yellow when ccache mount is down", () => {
    expect(getHealthColor(makeStats({ ccacheMount: false }))).toBe("yellow")
  })

  it("returns yellow when ccache sync is down", () => {
    expect(getHealthColor(makeStats({ ccacheSync: false }))).toBe("yellow")
  })

  it("returns green when healthy", () => {
    expect(getHealthColor(makeStats())).toBe("green")
  })
})
