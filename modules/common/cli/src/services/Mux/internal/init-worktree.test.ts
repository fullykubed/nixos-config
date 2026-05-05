import { describe, it, expect } from "bun:test"
import { removeNestedPaths, findConflicts } from "./init-worktree"

describe("removeNestedPaths", () => {
  it("returns empty for empty input", () => {
    expect(removeNestedPaths([])).toEqual([])
  })

  it("keeps a single entry", () => {
    expect(removeNestedPaths(["a"])).toEqual(["a"])
  })

  it("keeps unrelated paths", () => {
    expect(removeNestedPaths(["a", "b", "c"])).toEqual(["a", "b", "c"])
  })

  it("removes a file nested inside a directory", () => {
    expect(removeNestedPaths(["src", "src/foo.ts"])).toEqual(["src"])
  })

  it("removes deeply nested paths", () => {
    expect(removeNestedPaths(["src", "src/a/b/c.ts"])).toEqual(["src"])
  })

  it("removes multiple nested children", () => {
    const input = ["src", "src/a.ts", "src/b.ts", "src/c/d.ts"]
    expect(removeNestedPaths(input)).toEqual(["src"])
  })

  it("keeps sibling directories", () => {
    const input = ["src", "src/foo.ts", "lib", "lib/bar.ts"]
    expect(removeNestedPaths(input)).toEqual(["lib", "src"])
  })

  it("does not treat prefix-matching names as nested", () => {
    expect(removeNestedPaths(["src", "srclib"])).toEqual(["src", "srclib"])
  })

  it("handles nested directories at multiple levels", () => {
    const input = ["a", "a/b", "a/b/c", "a/b/c/d.ts"]
    expect(removeNestedPaths(input)).toEqual(["a"])
  })

  it("keeps independent subtrees", () => {
    const input = ["a/b", "a/c", "b/c"]
    expect(removeNestedPaths(input)).toEqual(["a/b", "a/c", "b/c"])
  })

  it("removes nested under a mid-level directory", () => {
    const input = ["a/b", "a/b/c.ts", "a/d.ts"]
    expect(removeNestedPaths(input)).toEqual(["a/b", "a/d.ts"])
  })

  it("handles unsorted input", () => {
    const input = ["src/foo.ts", "src", "lib/bar.ts", "lib"]
    expect(removeNestedPaths(input)).toEqual(["lib", "src"])
  })

  it("handles dot-prefixed paths", () => {
    const input = [".config", ".config/settings.json", ".env"]
    expect(removeNestedPaths(input)).toEqual([".config", ".env"])
  })

  it("handles 10,000 files under 100 directories", () => {
    const input: string[] = []
    for (let dir = 0; dir < 100; dir++) {
      input.push(`dir-${dir}`)
      for (let file = 0; file < 100; file++) {
        input.push(`dir-${dir}/file-${file}.ts`)
      }
    }
    // Shuffle to ensure sort-independence
    for (let i = input.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      ;[input[i], input[j]] = [input[j]!, input[i]!]
    }

    const result = removeNestedPaths(input)
    expect(result.length).toBe(100)
    for (const entry of result) {
      expect(entry).toMatch(/^dir-\d+$/)
    }
  })

  it("handles deeply nested tree with 5 levels and mixed overlap", () => {
    const input: string[] = []
    // Tree 1: top-level dir absorbs everything
    input.push("app")
    for (let a = 0; a < 10; a++) {
      input.push(`app/l1-${a}`)
      for (let b = 0; b < 10; b++) {
        input.push(`app/l1-${a}/l2-${b}`)
        for (let c = 0; c < 5; c++) {
          input.push(`app/l1-${a}/l2-${b}/l3-${c}`)
          input.push(`app/l1-${a}/l2-${b}/l3-${c}/file.ts`)
        }
      }
    }
    // Tree 2: mid-level dirs, no common root
    for (let i = 0; i < 20; i++) {
      input.push(`lib/mod-${i}`)
      input.push(`lib/mod-${i}/index.ts`)
      input.push(`lib/mod-${i}/utils.ts`)
    }

    const result = removeNestedPaths(input)
    // "app" absorbs its entire subtree
    expect(result).toContain("app")
    expect(result.filter((p) => p.startsWith("app/"))).toEqual([])
    // Each lib/mod-N absorbs its files
    const libEntries = result.filter((p) => p.startsWith("lib/"))
    expect(libEntries.length).toBe(20)
    for (const entry of libEntries) {
      expect(entry).toMatch(/^lib\/mod-\d+$/)
    }
  })

  it("handles 50,000 flat files with no nesting", () => {
    const input = Array.from({ length: 50_000 }, (_, i) => `file-${String(i).padStart(6, "0")}.ts`)

    const result = removeNestedPaths(input)
    expect(result.length).toBe(50_000)
  })
})

describe("findConflicts", () => {
  it("returns empty when no overlap", () => {
    expect(findConflicts(["a", "b"], ["c", "d"])).toEqual([])
  })

  it("returns empty when both are empty", () => {
    expect(findConflicts([], [])).toEqual([])
  })

  it("detects exact match", () => {
    expect(findConflicts([".envrc"], [".envrc"])).toEqual([".envrc"])
  })

  it("detects copy path nested inside link path", () => {
    expect(findConflicts(["node_modules/foo/index.js"], ["node_modules"])).toEqual(["node_modules"])
  })

  it("detects link path nested inside copy path", () => {
    expect(findConflicts(["vendor"], ["vendor/foo.js"])).toEqual(["vendor"])
  })

  it("does not treat prefix-matching names as conflicts", () => {
    expect(findConflicts(["src"], ["srclib"])).toEqual([])
  })

  it("deduplicates conflict entries", () => {
    const result = findConflicts(["a/b", "a/c"], ["a"])
    expect(result).toEqual(["a"])
  })

  it("reports multiple independent conflicts", () => {
    const result = findConflicts([".env", "vendor"], [".env", "vendor"])
    expect([...result].sort()).toEqual([".env", "vendor"])
  })
})
