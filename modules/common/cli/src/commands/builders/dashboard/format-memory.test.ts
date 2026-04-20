import { describe, it, expect } from "bun:test"
import { formatMemory } from "./format-memory"

describe("formatMemory", () => {
  it("formats KB range", () => {
    expect(formatMemory(512)).toBe("512KB")
    expect(formatMemory(1)).toBe("1KB")
    expect(formatMemory(0)).toBe("0KB")
  })

  it("formats MB range", () => {
    expect(formatMemory(1025)).toBe("1.0MB")
    expect(formatMemory(2048)).toBe("2.0MB")
    expect(formatMemory(1536)).toBe("1.5MB")
    expect(formatMemory(1048575)).toBe("1024.0MB")
  })

  it("formats GB range", () => {
    expect(formatMemory(1048577)).toBe("1.0GB")
    expect(formatMemory(2097152)).toBe("2.0GB")
    expect(formatMemory(16777216)).toBe("16.0GB")
  })

  it("handles decimal precision", () => {
    expect(formatMemory(1536)).toBe("1.5MB")
    expect(formatMemory(1572865)).toBe("1.5GB")
  })
})
