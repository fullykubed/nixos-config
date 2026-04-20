import { describe, it, expect } from "bun:test"
import { parseRemoteCommand } from "./parse-remote-command"

describe("parseRemoteCommand", () => {
  it("returns empty array when no -- separator", () => {
    expect(parseRemoteCommand(["builder-1"], "builder-1")).toEqual([])
    expect(parseRemoteCommand(["builder-1", "foo"], "builder-1")).toEqual([])
  })

  it("returns args after -- separator", () => {
    expect(parseRemoteCommand(["builder-1", "--", "ls", "-la"], "builder-1"))
      .toEqual(["ls", "-la"])
  })

  it("returns empty array when -- has nothing after it", () => {
    expect(parseRemoteCommand(["builder-1", "--"], "builder-1")).toEqual([])
  })

  it("handles multiple args after --", () => {
    expect(parseRemoteCommand(["--", "cat", "/etc/hostname"], "builder-1"))
      .toEqual(["cat", "/etc/hostname"])
  })
})
