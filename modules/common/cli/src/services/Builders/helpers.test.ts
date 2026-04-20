import { describe, it, expect } from "bun:test"
import { normalizeName, isBuilderName, builderType, serverTypeFor } from "./helpers"
import { BUILDER_CONFIG } from "./config"

describe("normalizeName", () => {
  it("converts bare number to builder-N", () => {
    expect(normalizeName("1")).toBe("builder-1")
    expect(normalizeName("42")).toBe("builder-42")
  })

  it("converts big-N to big-builder-N", () => {
    expect(normalizeName("big-1")).toBe("big-builder-1")
    expect(normalizeName("big-99")).toBe("big-builder-99")
  })

  it("passes through full builder names unchanged", () => {
    expect(normalizeName("builder-1")).toBe("builder-1")
    expect(normalizeName("big-builder-3")).toBe("big-builder-3")
  })

  it("passes through non-matching input unchanged", () => {
    expect(normalizeName("foo")).toBe("foo")
    expect(normalizeName("my-server")).toBe("my-server")
  })
})

describe("isBuilderName", () => {
  it("accepts valid builder names", () => {
    expect(isBuilderName("builder-1")).toBe(true)
    expect(isBuilderName("builder-42")).toBe(true)
    expect(isBuilderName("big-builder-1")).toBe(true)
    expect(isBuilderName("big-builder-99")).toBe(true)
  })

  it("rejects invalid names", () => {
    expect(isBuilderName("foo")).toBe(false)
    expect(isBuilderName("builder-")).toBe(false)
    expect(isBuilderName("builder-abc")).toBe(false)
    expect(isBuilderName("big-1")).toBe(false)
  })

  it("rejects edge cases", () => {
    expect(isBuilderName("")).toBe(false)
    expect(isBuilderName("builder")).toBe(false)
    expect(isBuilderName("builder-1-extra")).toBe(false)
  })
})

describe("builderType", () => {
  it("detects regular builders", () => {
    expect(builderType("builder-1")).toBe("regular")
    expect(builderType("builder-99")).toBe("regular")
  })

  it("detects big builders", () => {
    expect(builderType("big-builder-1")).toBe("big")
    expect(builderType("big-builder-42")).toBe("big")
  })
})

describe("serverTypeFor", () => {
  it("maps regular builders to regular server type", () => {
    expect(serverTypeFor("builder-1")).toBe(BUILDER_CONFIG.regularServerType)
  })

  it("maps big builders to big server type", () => {
    expect(serverTypeFor("big-builder-1")).toBe(BUILDER_CONFIG.bigServerType)
  })
})
