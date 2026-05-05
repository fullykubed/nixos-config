import { describe, it, expect } from "bun:test"
import { buildSshArgs } from "./build-ssh-args"

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