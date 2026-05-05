import { describe, it, expect } from "bun:test"
import { parseWorktreeList } from "./worktree-list"
import { BranchName, WorktreePath } from "../types"

describe("parseWorktreeList", () => {
  it("should return empty array for empty output", () => {
    expect(parseWorktreeList("")).toEqual([])
    expect(parseWorktreeList("   ")).toEqual([])
  })

  it("should parse single worktree", () => {
    const output = `worktree /home/user/repo
HEAD abc123
branch refs/heads/main`

    const result = parseWorktreeList(output, "main")
    expect(result).toEqual([{
      path: WorktreePath("/home/user/repo"),
      head: "abc123",
      branch: BranchName("main"),
      isPrimary: true,
      bare: false,
      locked: false,
      prunable: false,
    }])
  })

  it("should mark isPrimary based on primaryBranch argument", () => {
    const output = `worktree /home/user/repo
HEAD abc123
branch refs/heads/main

worktree /home/user/repo-feature
HEAD def456
branch refs/heads/feature/test

worktree /home/user/repo-detached
HEAD 789abc
detached`

    const result = parseWorktreeList(output, "main")
    expect(result).toEqual([
      {
        path: WorktreePath("/home/user/repo"),
        head: "abc123",
        branch: BranchName("main"),
        isPrimary: true,
        bare: false,
        locked: false,
        prunable: false,
      },
      {
        path: WorktreePath("/home/user/repo-feature"),
        head: "def456",
        branch: BranchName("feature/test"),
        isPrimary: false,
        bare: false,
        locked: false,
        prunable: false,
      },
      {
        path: WorktreePath("/home/user/repo-detached"),
        head: "789abc",
        branch: null,
        isPrimary: false,
        bare: false,
        locked: false,
        prunable: false,
      }
    ])
  })

  it("should set all isPrimary to false when no primaryBranch given", () => {
    const output = `worktree /home/user/repo
HEAD abc123
branch refs/heads/main`

    const result = parseWorktreeList(output)
    expect(result[0]!.isPrimary).toBe(false)
  })

  it("should parse worktree with special flags", () => {
    const output = `worktree /home/user/repo
HEAD abc123
branch refs/heads/main

worktree /home/user/repo-locked
HEAD def456
branch refs/heads/feature
locked reason: manually locked

worktree /home/user/repo-prunable
HEAD 789abc
branch refs/heads/old-feature
prunable`

    const result = parseWorktreeList(output, "main")
    expect(result).toEqual([
      {
        path: WorktreePath("/home/user/repo"),
        head: "abc123",
        branch: BranchName("main"),
        isPrimary: true,
        bare: false,
        locked: false,
        prunable: false,
      },
      {
        path: WorktreePath("/home/user/repo-locked"),
        head: "def456",
        branch: BranchName("feature"),
        isPrimary: false,
        bare: false,
        locked: true,
        prunable: false,
      },
      {
        path: WorktreePath("/home/user/repo-prunable"),
        head: "789abc",
        branch: BranchName("old-feature"),
        isPrimary: false,
        bare: false,
        locked: false,
        prunable: true,
      }
    ])
  })

  it("should mark non-first worktree as primary when it matches primaryBranch", () => {
    const output = `worktree /home/user/repo
HEAD abc123
branch refs/heads/develop

worktree /home/user/repo-main
HEAD def456
branch refs/heads/main`

    const result = parseWorktreeList(output, "main")
    expect(result[0]!.isPrimary).toBe(false)
    expect(result[1]!.isPrimary).toBe(true)
  })
})
