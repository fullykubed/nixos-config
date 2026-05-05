# Testing Patterns

## Unit tests

Each method has a co-located `.test.ts` file in `public/`. Tests provide only the services that method actually uses, via `Effect.provideService` with a partial mock:

```ts
// services/Builders/public/exists.test.ts
import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { HcloudService } from "../../Hcloud"
import { exists } from "./exists"

describe("exists", () => {
  it("returns true when server exists", async () => {
    expect(await Effect.runPromise(
      exists("builder-1").pipe(Effect.provideService(HcloudService, {
        serverExists: () => Effect.succeed(true),
      } as any))
    )).toBe(true)
  })
})
```

For methods with multiple dependencies, build a full context:

```ts
Effect.provide(
  Context.empty().pipe(
    Context.add(HcloudService, mockHcloud),
    Context.add(TailscaleService, mockTailscale),
  )
)
```

To test error paths, use `Effect.runPromiseExit` and inspect the exit:

```ts
// services/Builders/public/resolve-ip.test.ts
it("fails with BuilderUnreachableError", async () => {
  const exit = await Effect.runPromiseExit(
    resolveIP("builder-1").pipe(Effect.provideService(TailscaleService, {
      resolveIP: (h: string) =>
        Effect.fail(new TailscaleDNSResolutionError({ hostname: h, error: "not found" })),
    } as any))
  )
  expect(Exit.isFailure(exit)).toBe(true)
  if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
    expect(exit.cause.error._tag).toBe("BuilderUnreachableError")
  }
})
```

## Shared mocks

Methods that return complex result types (config objects, branded types) provide a co-located `.mock.ts` file next to the implementation. These export a factory function that returns a mock with sensible defaults, accepting optional overrides:

```ts
// services/Git/public/get-project-config.mock.ts
export const mockGetProjectConfig = (overrides?: Partial<ProjectConfigResult>) =>
  () => Effect.succeed({ ...MOCK_PROJECT_CONFIG, ...overrides })
```

Usage in tests — the factory returns a function matching the service method signature:

```ts
import { mockGetProjectConfig } from "../../Git/public/get-project-config.mock"

// Default config with mock projectPath and projectId
getProjectConfig: mockGetProjectConfig()

// Override specific fields
getProjectConfig: mockGetProjectConfig({ projectPath: ProjectPath("/my/repo") })
getProjectConfig: mockGetProjectConfig({ tmux_session: "my-project" })
```

When a test needs to spy on arguments while still using the shared mock return value, call the factory inside a wrapper:

```ts
getProjectConfig: (dir) => {
  capturedDir = dir
  return mockGetProjectConfig({ projectPath: ProjectPath("/repo") })()
},
```

Place new `.mock.ts` files next to the implementation they mock (e.g. `public/foo.mock.ts` for `public/foo.ts`). Name the export `mockFoo` matching the method name.

## `test-helpers.ts`

Services with many dependencies provide a `test-helpers.ts` with mock factories and fixtures:

```ts
// services/Builders/test-helpers.ts
export const baseHcloud = (
  overrides: Partial<HcloudServiceShape> = {}
): HcloudServiceShape => ({
  serverExists: () => Effect.succeed(false),
  getServer: (n) => Effect.fail(new HcloudServerNotFound({ name: String(n) })),
  listServers: () => Effect.succeed([]),
  // ...all methods with sensible defaults...
  ...overrides,
})

export function makeTestContext(opts: {
  hcloud?: Partial<HcloudServiceShape>
  tailscale?: Partial<TailscaleServiceShape>
  // ...
}) {
  return Context.empty().pipe(
    Context.add(HcloudService, baseHcloud(opts.hcloud)),
    Context.add(TailscaleService, baseTailscale(opts.tailscale)),
    // ...
  )
}
```

Tests then override only the methods they care about:

```ts
const ctx = makeTestContext({ hcloud: { serverExists: () => Effect.succeed(true) } })
```

## Suppressing log output

`Effect.log` calls write `timestamp=...` lines to the console. **Tests must suppress these** so they don't pollute `bun test` output. Use the helpers from `src/lib/test-logger.ts`.

### When you don't need to inspect logs

Use `SilentLogger` — a Layer that replaces the default logger with a no-op:

```ts
import { SilentLogger } from "../../../lib/test-logger"

// Single-service test
exists("builder-1").pipe(
  Effect.provideService(HcloudService, mock),
  Effect.provide(SilentLogger),
)

// Multi-service provide helper
const provide = (hcloud, tailscale) =>
  (effect) =>
    effect.pipe(
      Effect.provide(Context.empty().pipe(
        Context.add(HcloudService, hcloud),
        Context.add(TailscaleService, tailscale),
      )),
      Effect.provide(SilentLogger),
    )

// Integration test layer
const TestLayer = GitLive.pipe(
  Layer.provideMerge(ShellLive),
  Layer.provideMerge(BunContext.layer),
  Layer.merge(SilentLogger),
)
```

### When you need to assert on logged messages

Use `makeTestLogger()` — returns a capturing logger Layer and a `messages` array:

```ts
import { makeTestLogger } from "../../../lib/test-logger"

it("logs removal message", async () => {
  const { messages, layer } = makeTestLogger()

  await Effect.runPromise(
    removeHandler(parsed).pipe(
      Effect.provideService(TmuxService, tmux),
      Effect.provide(layer),
    )
  )

  expect(messages).toContainEqual(
    expect.stringContaining("Removed worktree")
  )
})
```

## Integration tests

Integration tests live in an `integration-tests/` subdirectory. A `setup.ts` provides helpers that create real resources (temp directories, git repos, tmux sessions) and a `run` function that provides a real service layer:

```ts
// services/Git/integration-tests/setup.ts
const TestLayer = ShellLive.pipe(Layer.provideMerge(BunContext.layer))

export const run = <A, E>(effect: Effect.Effect<A, E, ShellService>) =>
  effect.pipe(Effect.provide(TestLayer), Effect.runPromise)

export const createTmpRepo = (): Promise<string> =>
  run(Effect.gen(function* () {
    const dir = mkdtempSync(join(tmpdir(), "git-integ-"))
    yield* git(dir, "init", "-b", "main")
    // ...
    return dir
  }))
```
