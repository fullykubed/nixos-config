import { describe, expect, test } from "bun:test"
import { isAbsolutePath, AbsolutePath } from "./absolute-path"

describe("isAbsolutePath", () => {
  test("accepts root path", () => {
    expect(isAbsolutePath("/")).toBe(true)
  })

  test("accepts absolute paths", () => {
    expect(isAbsolutePath("/home/user")).toBe(true)
    expect(isAbsolutePath("/tmp/file.txt")).toBe(true)
  })

  test("rejects empty string", () => {
    expect(isAbsolutePath("")).toBe(false)
  })

  test("rejects relative paths", () => {
    expect(isAbsolutePath("relative/path")).toBe(false)
    expect(isAbsolutePath("./relative")).toBe(false)
    expect(isAbsolutePath("no-slash")).toBe(false)
  })
})

describe("AbsolutePath constructor", () => {
  test("returns branded value for valid path", () => {
    const result = AbsolutePath("/home/user")
    expect(result as string).toBe("/home/user")
  })

  test("throws for invalid path", () => {
    expect(() => AbsolutePath("relative")).toThrow()
  })
})
