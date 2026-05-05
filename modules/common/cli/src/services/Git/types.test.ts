import { describe, it, expect } from "bun:test"
import { isValidBranchName, isValidProjectId } from "./types"

describe("isValidBranchName", () => {
  const valid = ["main", "feature/branch", "fix-123", "a", "refs/heads/main", "feature/add-thing", "v1.0.0"]
  for (const name of valid) {
    it(`accepts '${name}'`, () => {
      expect(isValidBranchName(name)).toBe(true)
    })
  }

  const invalid: [string, string][] = [
    ["", "empty string"],
    ["@", "bare @"],
    ["-start", "starts with -"],
    [".hidden", "starts with ."],
    ["end.", "ends with ."],
    ["/start", "starts with /"],
    ["end/", "ends with /"],
    ["end.lock", "ends with .lock"],
    ["a..b", "contains .."],
    ["a//b", "contains //"],
    ["a@{b}", "contains @{"],
    ["a/.hidden", "contains /."],
    ["sp ace", "contains space"],
    ["a~b", "contains ~"],
    ["a^b", "contains ^"],
    ["a:b", "contains :"],
    ["a?b", "contains ?"],
    ["a*b", "contains *"],
    ["a[b", "contains ["],
    ["a\\b", "contains \\"],
    ["a\x01b", "contains control char"],
    ["a\x7fb", "contains DEL"],
  ]
  for (const [name, reason] of invalid) {
    it(`rejects '${name}' (${reason})`, () => {
      expect(isValidBranchName(name)).toBe(false)
    })
  }
})

describe("isValidProjectId", () => {
  const valid = [
    "550e8400-e29b-41d4-a716-446655440000",
    "00000000-0000-0000-0000-000000000000",
    "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
    "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  ]
  for (const id of valid) {
    it(`accepts '${id}'`, () => {
      expect(isValidProjectId(id)).toBe(true)
    })
  }

  const invalid: [string, string][] = [
    ["", "empty string"],
    ["not-a-uuid", "random string"],
    ["550e8400e29b41d4a716446655440000", "no dashes"],
    ["550e8400-e29b-41d4-a716-44665544000", "too short"],
    ["550e8400-e29b-41d4-a716-4466554400000", "too long"],
    ["550e8400-e29b-41d4-a716-44665544000g", "non-hex char"],
    ["550e8400-e29b-41d4-a716", "truncated"],
  ]
  for (const [id, reason] of invalid) {
    it(`rejects '${id}' (${reason})`, () => {
      expect(isValidProjectId(id)).toBe(false)
    })
  }
})
