import { describe, it, expect, afterEach, setSystemTime } from "bun:test"
import { calculateUptimeHours } from "./calculate-uptime"

describe("calculateUptimeHours", () => {
  afterEach(() => {
    setSystemTime()
  })

  it("calculates correct uptime hours for a known date difference", () => {
    setSystemTime(new Date("2024-01-02T00:00:00Z"))
    const hours = calculateUptimeHours("2024-01-01T00:00:00Z")
    expect(hours).toBe(24)
  })

  it("calculates fractional hours", () => {
    setSystemTime(new Date("2024-01-01T01:30:00Z"))
    const hours = calculateUptimeHours("2024-01-01T00:00:00Z")
    expect(hours).toBe(1.5)
  })

  it("returns 0 for just-created servers", () => {
    setSystemTime(new Date("2024-01-01T00:00:00Z"))
    const hours = calculateUptimeHours("2024-01-01T00:00:00Z")
    expect(hours).toBe(0)
  })
})
