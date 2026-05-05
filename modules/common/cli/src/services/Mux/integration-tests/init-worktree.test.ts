import { existsSync, rmSync, unlinkSync } from "node:fs"
import { join } from "node:path"
import { afterAll, beforeAll, describe, expect, it } from "bun:test"
import { Effect, Exit } from "effect"
import {
  type RepoFixture, createNormalRepo, createBareWorktreeRepo,
  exists, git, isSymlink, readFile, readlink, run, writeFile, TestLayer,
} from "./setup.test"
import { initWorktree } from "../internal/init-worktree"
import { WorktreePath } from "../../Git"

// ── Parameterized test suite ────────────────────────────────────────

const initWorktreeSuite = (
  suiteName: string,
  createRepo: () => Promise<RepoFixture>,
) => {
  describe.serial(suiteName, () => {
    let fixture: RepoFixture
    /** Shorthand for the primary worktree dir (where untracked files live). */
    let primary: string

    beforeAll(async () => {
      fixture = await createRepo()
      primary = fixture.primaryDir
    })

    afterAll(() => {
      for (const dir of fixture.cleanupDirs) {
        rmSync(dir, { recursive: true, force: true })
      }
    })

    // The git common dir is where getProjectConfig reads project.json from.
    const gitCommonDir = () =>
      fixture.gitDir === fixture.primaryDir
        ? join(fixture.gitDir, ".git")  // Normal repo: commondir is .git subdir
        : fixture.gitDir                // Bare repo: gitDir is already the common dir

    // Helper: write project.json to git common dir, create branch + worktree
    const setupWorktree = (branch: string, config: object) => {
      writeFile(gitCommonDir(), "project.json", JSON.stringify(config))
      return run(
        Effect.gen(function* () {
          const wtPath = join(fixture.configDir, branch)
          yield* git(fixture.gitDir, "worktree", "add", wtPath, "-b", branch)
          return wtPath
        }),
      )
    }

    const cleanupWorktree = (wtPath: string, branch: string) =>
      run(
        Effect.gen(function* () {
          yield* git(fixture.gitDir, "worktree", "remove", "--force", wtPath).pipe(Effect.ignore)
          yield* git(fixture.gitDir, "branch", "-D", branch).pipe(Effect.ignore)
        }),
      ).then(() => {
        const configPath = join(gitCommonDir(), "project.json")
        if (existsSync(configPath)) unlinkSync(configPath)
      })

    describe.serial("with no config", () => {
      let wtPath: string

      beforeAll(async () => {
        wtPath = join(fixture.configDir, "wt-no-config")
        await run(
          Effect.gen(function* () {
            yield* git(fixture.gitDir, "worktree", "add", wtPath, "-b", "no-config")
          }),
        )
      })

      afterAll(() => cleanupWorktree(wtPath, "no-config"))

      it("succeeds with no project.json (defaults have empty copy list)", () =>
        run(initWorktree(WorktreePath(wtPath))))
    })

    describe.serial("copies individual files matching globs", () => {
      let wtPath: string

      beforeAll(async () => {
        wtPath = await setupWorktree("feat-files", {
          primary_branch: "main",
          worktree: { files: { copy: [".env*", "generated/**"] }, post_create: [] },
        })
        writeFile(primary, ".envrc", "use flake")
        writeFile(primary, ".env.local", "SECRET=abc")
        writeFile(primary, "generated/output.js", "built-code")
        writeFile(primary, "untracked.txt", "should not be copied")
        await run(initWorktree(WorktreePath(wtPath)))
      })

      afterAll(() => cleanupWorktree(wtPath, "feat-files"))

      it("copies matched files into the worktree", () => {
        expect(readFile(wtPath, ".envrc")).toBe("use flake")
        expect(readFile(wtPath, ".env.local")).toBe("SECRET=abc")
        expect(readFile(wtPath, "generated/output.js")).toBe("built-code")
      })

      it("does not copy files that don't match any glob", () => {
        expect(exists(wtPath, "untracked.txt")).toBe(false)
      })
    })

    describe.serial("copies entire directories", () => {
      let wtPath: string

      beforeAll(async () => {
        wtPath = await setupWorktree("feat-dirs", {
          primary_branch: "main",
          worktree: { files: { copy: ["vendor"] }, post_create: [] },
        })
        writeFile(primary, "vendor/foo/index.js", "module.exports = 1")
        writeFile(primary, "vendor/foo/package.json", "{}")
        writeFile(primary, "vendor/bar/index.js", "module.exports = 2")
      })

      afterAll(() => cleanupWorktree(wtPath, "feat-dirs"))

      it("recursively copies the directory", async () => {
        await run(initWorktree(WorktreePath(wtPath)))

        expect(readFile(wtPath, "vendor/foo/index.js")).toBe("module.exports = 1")
        expect(readFile(wtPath, "vendor/foo/package.json")).toBe("{}")
        expect(readFile(wtPath, "vendor/bar/index.js")).toBe("module.exports = 2")
      })
    })

    describe.serial("runs post_create hooks", () => {
      let wtPath: string

      beforeAll(async () => {
        wtPath = await setupWorktree("feat-hooks", {
          primary_branch: "main",
          worktree: {
            files: { copy: [] },
            post_create: [
              "echo hello > hook-output.txt",
              "mkdir -p generated && echo done > generated/marker.txt",
            ],
          },
        })
      })

      afterAll(() => cleanupWorktree(wtPath, "feat-hooks"))

      it("executes hooks in the worktree directory", async () => {
        await run(initWorktree(WorktreePath(wtPath)))

        expect(readFile(wtPath, "hook-output.txt")).toBe("hello\n")
        expect(readFile(wtPath, "generated/marker.txt")).toBe("done\n")
      })
    })

    describe.serial("handles glob with no matches", () => {
      let wtPath: string

      beforeAll(async () => {
        wtPath = await setupWorktree("feat-nomatch", {
          primary_branch: "main",
          worktree: { files: { copy: ["*.nonexistent", "missing-dir/**"] }, post_create: [] },
        })
      })

      afterAll(() => cleanupWorktree(wtPath, "feat-nomatch"))

      it("succeeds without error", () =>
        run(initWorktree(WorktreePath(wtPath))))
    })

    describe.serial("symlinks files matching link globs", () => {
      let wtPath: string

      beforeAll(async () => {
        wtPath = await setupWorktree("feat-link", {
          primary_branch: "main",
          worktree: {
            files: { copy: [], link: [".envrc", "linked-vendor"] },
            post_create: [],
          },
        })
        writeFile(primary, ".envrc", "use flake")
        writeFile(primary, "linked-vendor/foo/index.js", "module.exports = 1")
        writeFile(primary, "not-linked.txt", "should not appear")
        await run(initWorktree(WorktreePath(wtPath)))
      })

      afterAll(() => cleanupWorktree(wtPath, "feat-link"))

      it("creates symlinks for matched entries", () => {
        expect(isSymlink(wtPath, ".envrc")).toBe(true)
        expect(isSymlink(wtPath, "linked-vendor")).toBe(true)
      })

      it("symlinks point back to the primary worktree", () => {
        expect(readlink(wtPath, ".envrc")).toBe(join(primary, ".envrc"))
        expect(readlink(wtPath, "linked-vendor")).toBe(join(primary, "linked-vendor"))
      })

      it("symlinked content is readable through the link", () => {
        expect(readFile(wtPath, ".envrc")).toBe("use flake")
        expect(readFile(wtPath, "linked-vendor/foo/index.js")).toBe("module.exports = 1")
      })

      it("does not link files outside the glob patterns", () => {
        expect(exists(wtPath, "not-linked.txt")).toBe(false)
      })
    })

    describe.serial("copy and link together", () => {
      let wtPath: string

      beforeAll(async () => {
        wtPath = await setupWorktree("feat-both", {
          primary_branch: "main",
          worktree: {
            files: { copy: [".env*"], link: ["nm"] },
            post_create: [],
          },
        })
        writeFile(primary, ".env", "KEY=val")
        writeFile(primary, "nm/pkg/index.js", "// pkg")
      })

      afterAll(() => cleanupWorktree(wtPath, "feat-both"))

      it("copies .env files and symlinks nm", async () => {
        await run(initWorktree(WorktreePath(wtPath)))

        expect(exists(wtPath, ".env")).toBe(true)
        expect(isSymlink(wtPath, ".env")).toBe(false)
        expect(readFile(wtPath, ".env")).toBe("KEY=val")

        expect(isSymlink(wtPath, "nm")).toBe(true)
        expect(readFile(wtPath, "nm/pkg/index.js")).toBe("// pkg")
      })
    })

    describe.serial("fails when copy and link globs overlap", () => {
      let wtPath: string

      beforeAll(async () => {
        wtPath = await setupWorktree("feat-conflict", {
          primary_branch: "main",
          worktree: {
            files: { copy: ["shared/**"], link: ["shared"] },
            post_create: [],
          },
        })
        writeFile(primary, "shared/util.ts", "// util")
      })

      afterAll(() => cleanupWorktree(wtPath, "feat-conflict"))

      it("fails with MuxInitWorktreeError", async () => {
        const exit = await initWorktree(WorktreePath(wtPath)).pipe(
          Effect.provide(TestLayer),
          Effect.runPromiseExit,
        )

        expect(Exit.isFailure(exit)).toBe(true)
        if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
          expect(exit.cause.error._tag).toBe("MuxInitWorktreeError")
          if (exit.cause.error._tag === "MuxInitWorktreeError") {
            expect(exit.cause.error.paths).toContain("shared")
          }
        }
      })
    })
  })
}

// ── Run against both repo types ─────────────────────────────────────

initWorktreeSuite("initWorktree (normal repo)", createNormalRepo)
initWorktreeSuite("initWorktree (bare worktree repo)", createBareWorktreeRepo)
