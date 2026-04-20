import { describe, it, expect } from "bun:test"
import { parseStats } from "./parse-stats"

const validOutput = [
  "5",   // builds
  "42",  // cpuPercent
  "4000000", // memUsedKb
  "8000000", // memTotalKb
  "1000", // diskReadSectors
  "2000", // diskWriteSectors
  "50000000", // diskTotalKb
  "25000000", // diskUsedKb
  "50",  // diskPercent
  "3",   // sshSessions
  "running", // tailscaleStatus
  "2",   // queuePending
  "10",  // queueDone
  "0",   // idleCount
  "100", // ccacheHits
  "20",  // ccacheMisses
  "500000", // ccacheSizeKb
  "1",   // ccacheMount
  "1",   // ccacheSync
  "7",   // serveCount
].join("|")

describe("parseStats", () => {
  it("parses valid 20-field input into BuilderStats", () => {
    const result = parseStats("builder-1", validOutput)
    expect(result.name).toBe("builder-1")
    expect(result.reachable).toBe(true)
    expect(result.builds).toBe(5)
    expect(result.cpuPercent).toBe(42)
    expect(result.memUsedKb).toBe(4000000)
    expect(result.memTotalKb).toBe(8000000)
    expect(result.diskReadSectors).toBe(1000)
    expect(result.diskWriteSectors).toBe(2000)
    expect(result.diskTotalKb).toBe(50000000)
    expect(result.diskUsedKb).toBe(25000000)
    expect(result.diskPercent).toBe(50)
    expect(result.sshSessions).toBe(3)
    expect(result.tailscaleStatus).toBe("running")
    expect(result.queuePending).toBe(2)
    expect(result.queueDone).toBe(10)
    expect(result.idleCount).toBe(0)
    expect(result.ccacheHits).toBe(100)
    expect(result.ccacheMisses).toBe(20)
    expect(result.ccacheSizeKb).toBe(500000)
    expect(result.ccacheMount).toBe(true)
    expect(result.ccacheSync).toBe(true)
    expect(result.serveCount).toBe(7)
  })

  it("throws when field count is wrong", () => {
    expect(() => parseStats("builder-1", "1|2|3")).toThrow("Expected 20 fields, got 3")
    expect(() => parseStats("builder-1", "a")).toThrow("Expected 20 fields, got 1")
  })

  it("parses boolean fields from 1/0 strings", () => {
    const withFalse = validOutput.replace("|1|1|", "|0|0|")
    const result = parseStats("builder-1", withFalse)
    expect(result.ccacheMount).toBe(false)
    expect(result.ccacheSync).toBe(false)
  })

  it("defaults non-numeric integer fields to 0", () => {
    const withNaN = "abc|0|0|0|0|0|0|0|0|0|unknown|0|0|0|0|0|0|1|1|0"
    const result = parseStats("builder-1", withNaN)
    expect(result.builds).toBe(0)
  })
})
