import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { makeStoreLive, StoreService } from "../../Store"
import { ProjectId, ProjectPath } from "../../Git"
import { trackProject } from "./track-project"

const PID_1 = ProjectId("aaaaaaaa-0000-0000-0000-000000000001")
const PID_2 = ProjectId("aaaaaaaa-0000-0000-0000-000000000002")
const PID_3 = ProjectId("aaaaaaaa-0000-0000-0000-000000000003")
const PID_4 = ProjectId("aaaaaaaa-0000-0000-0000-000000000004")

const findProject = (id: ProjectId) =>
  Effect.gen(function* () {
    const db = yield* StoreService
    return yield* Effect.tryPromise(() =>
      db.selectFrom("mux_projects")
        .select(["id", "path"])
        .where("id", "=", id)
        .executeTakeFirst()
    )
  })

describe("trackProject", () => {
  const TestStore = makeStoreLive(":memory:")
  const run = <A, E>(effect: Effect.Effect<A, E, any>) =>
    Effect.runPromise(effect.pipe(
      Effect.provide(TestStore),
    ) as Effect.Effect<A, E>)

  it("inserts a new project when id does not exist", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_1, ProjectPath("/home/user/new-repo"))

      const project = yield* findProject(PID_1)
      expect(project).toBeDefined()
      expect(project!.id).toBe(PID_1)
      expect(project!.path).toBe(ProjectPath("/home/user/new-repo"))
    }))
  })

  it("updates path when id already exists", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_2, ProjectPath("/home/user/old-path"))
      yield* trackProject(PID_2, ProjectPath("/home/user/new-path"))

      const project = yield* findProject(PID_2)
      expect(project!.path).toBe(ProjectPath("/home/user/new-path"))
    }))
  })

  it("handles multiple distinct projects", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_3, ProjectPath("/home/user/repo-a"))
      yield* trackProject(PID_4, ProjectPath("/home/user/repo-b"))

      const a = yield* findProject(PID_3)
      const b = yield* findProject(PID_4)
      expect(a!.path).toBe(ProjectPath("/home/user/repo-a"))
      expect(b!.path).toBe(ProjectPath("/home/user/repo-b"))
    }))
  })

  it("is idempotent with same id and path", async () => {
    await run(Effect.gen(function* () {
      yield* trackProject(PID_1, ProjectPath("/home/user/new-repo"))
      yield* trackProject(PID_1, ProjectPath("/home/user/new-repo"))
      const project = yield* findProject(PID_1)
      expect(project!.id).toBe(PID_1)
      expect(project!.path).toBe(ProjectPath("/home/user/new-repo"))
    }))
  })
})
