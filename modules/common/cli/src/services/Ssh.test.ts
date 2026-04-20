import { describe, it, expect } from "bun:test"
import { Effect, Exit, Layer } from "effect"
import {
  SshService,
  SshLive,
  buildSshArgs,
} from "./Ssh"
import { ShellService, ShellError } from "./Shell"

// ── buildSshArgs ────────────────────────────────────────────────────

describe("buildSshArgs", () => {
  it("generates correct default flags", () => {
    const args = buildSshArgs("10.0.0.1")
    expect(args).toContain("-F")
    expect(args).toContain("/dev/null")
    expect(args).toContain("-p")
    expect(args).toContain("3098")
    expect(args).toContain("-i")
    expect(args).toContain("/root/.ssh/builder-key")
    expect(args).toContain("remotebuild@10.0.0.1")
  })

  it("includes BatchMode=yes for non-interactive", () => {
    const args = buildSshArgs("10.0.0.1", undefined, { interactive: false })
    expect(args).toContain("BatchMode=yes")
  })

  it("excludes BatchMode for interactive", () => {
    const args = buildSshArgs("10.0.0.1", undefined, { interactive: true })
    expect(args.join(" ")).not.toContain("BatchMode")
  })

  it("uses custom port and identity file", () => {
    const args = buildSshArgs("10.0.0.1", {
      port: 22,
      identityFile: "/custom/key",
    })
    expect(args).toContain("22")
    expect(args).toContain("/custom/key")
  })

  it("includes StrictHostKeyChecking=yes always", () => {
    const args = buildSshArgs("10.0.0.1")
    expect(args).toContain("StrictHostKeyChecking=yes")
  })

  it("includes UserKnownHostsFile when knownHostsFile is set", () => {
    const args = buildSshArgs("10.0.0.1", { knownHostsFile: "/tmp/known" })
    expect(args.join(" ")).toContain("UserKnownHostsFile=/tmp/known")
  })

  it("includes ConnectTimeout when set", () => {
    const args = buildSshArgs("10.0.0.1", { connectTimeout: 10 })
    expect(args.join(" ")).toContain("ConnectTimeout=10")
  })

  it("uses custom user", () => {
    const args = buildSshArgs("10.0.0.1", { user: "root" })
    expect(args).toContain("root@10.0.0.1")
  })
})

// ── Error classification ────────────────────────────────────────────

const makeMockShell = (stderr: string) =>
  Layer.succeed(ShellService, ShellService.of({
    exec: () => Effect.fail(new ShellError({
      command: "ssh",
      exitCode: 255,
      stdout: "",
      stderr,
    })),
    execJson: () => Effect.fail(new ShellError({
      command: "ssh",
      exitCode: 255,
      stdout: "",
      stderr,
    })),
    execLines: () => Effect.fail(new ShellError({
      command: "ssh",
      exitCode: 255,
      stdout: "",
      stderr,
    })),
  }))

function extractFailureTag(exit: Exit.Exit<any, any>): string | undefined {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return (cause.error)?._tag
  return undefined
}

describe("SSH error classification", () => {
  it("classifies 'Connection refused' as SshConnectionError", async () => {
    const layer = SshLive.pipe(Layer.provide(makeMockShell("Connection refused")))
    const exit = await Effect.runPromiseExit(
      SshService.pipe(
        Effect.flatMap(svc => svc.exec("10.0.0.1", "echo hi")),
        Effect.provide(layer)
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("SshConnectionError")
  })

  it("classifies 'Permission denied' as SshAuthError", async () => {
    const layer = SshLive.pipe(Layer.provide(makeMockShell("Permission denied (publickey)")))
    const exit = await Effect.runPromiseExit(
      SshService.pipe(
        Effect.flatMap(svc => svc.exec("10.0.0.1", "echo hi")),
        Effect.provide(layer)
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("SshAuthError")
  })

  it("classifies 'timed out' as SshTimeoutError", async () => {
    const layer = SshLive.pipe(Layer.provide(makeMockShell("Connection timed out")))
    const exit = await Effect.runPromiseExit(
      SshService.pipe(
        Effect.flatMap(svc => svc.exec("10.0.0.1", "echo hi")),
        Effect.provide(layer)
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("SshTimeoutError")
  })

  it("classifies 'Host key verification failed' as SshHostKeyError", async () => {
    const layer = SshLive.pipe(Layer.provide(makeMockShell("Host key verification failed")))
    const exit = await Effect.runPromiseExit(
      SshService.pipe(
        Effect.flatMap(svc => svc.exec("10.0.0.1", "echo hi")),
        Effect.provide(layer)
      )
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("SshHostKeyError")
  })
})
