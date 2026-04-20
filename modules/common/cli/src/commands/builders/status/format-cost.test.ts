import { describe, it, expect } from "bun:test"
import { formatCost } from "./format-cost"

describe("formatCost", () => {
  it("formats integer to 4 decimal places", () => {
    expect(formatCost(5)).toBe("5.0000")
    expect(formatCost(100)).toBe("100.0000")
  })

  it("formats float to 4 decimal places", () => {
    expect(formatCost(1.2345)).toBe("1.2345")
    expect(formatCost(0.0534)).toBe("0.0534")
    expect(formatCost(0.1)).toBe("0.1000")
  })

  it("formats zero", () => {
    expect(formatCost(0)).toBe("0.0000")
  })
})
