import { describe, it, expect } from "bun:test"
import { Effect } from "effect"
import { FileSystem } from "@effect/platform"
import { createInstallScript } from "./install-script"

const testSecrets: Record<string, string> = {
  "/etc/ssh/builder-key.pub": "ssh-ed25519 AAAA...",
  "/run/agenix/builder-host-key": "fake-host-private-key-for-testing",
  "/etc/ssh/builder-host-key.pub": "ssh-ed25519 BBBB...",
  "/root/.ssh/cache-key": "fake-cache-private-key-for-testing",
  "/etc/ssh/cache-host-key.pub": "ssh-ed25519 CCCC...",
  "/run/agenix/niks3-api-token": "niks3-token-value",
  "/run/agenix/ccache-r2-access-key": "r2-access-key",
  "/run/agenix/ccache-r2-secret-key": "r2-secret-key",
  "/run/agenix/hetzner-api-token": "hcloud-token-value",
}

const mockFs = {
  readFileString: (path: string) => {
    const content = testSecrets[path]
    if (content === undefined) return Effect.fail(new Error(`file not found: ${path}`)) as never
    return Effect.succeed(content) as never
  },
} as unknown as FileSystem.FileSystem

const runInstallScript = (opts: { name: string; authKey: string; builderType: "regular" | "big" }) =>
  Effect.runPromise(createInstallScript(mockFs, opts))

describe("createInstallScript", () => {
  it("starts with bash shebang and set -euo pipefail", async () => {
    const script = await runInstallScript({
      name: "builder-1",
      authKey: "auth-key-123",
      builderType: "regular",
    })
    expect(script.startsWith("#!/usr/bin/env bash\nset -euo pipefail\n")).toBe(true)
  })

  it("creates required directories", async () => {
    const script = await runInstallScript({
      name: "builder-1",
      authKey: "auth-key-123",
      builderType: "regular",
    })
    expect(script).toContain("mkdir -p /var/lib/remotebuild/.ssh /root/.ssh /etc/ssh /etc/nix")
  })

  it("writes all secret files with correct content", async () => {
    const script = await runInstallScript({
      name: "builder-1",
      authKey: "auth-key-123",
      builderType: "regular",
    })

    expect(script).toContain("cat > /run/hcloud-token <<'SECRETEOF'\nhcloud-token-value\nSECRETEOF")
    expect(script).toContain("cat > /run/headscale-authkey <<'SECRETEOF'\nauth-key-123\nSECRETEOF")
    expect(script).toContain("cat > /run/builder-name <<'SECRETEOF'\nbuilder-1\nSECRETEOF")
    expect(script).toContain("cat > /var/lib/remotebuild/.ssh/authorized_keys <<'SECRETEOF'\nssh-ed25519 AAAA...\nSECRETEOF")
    expect(script).toContain("cat > /root/.ssh/authorized_keys <<'SECRETEOF'\nssh-ed25519 AAAA...\nSECRETEOF")
    expect(script).toContain("cat > /etc/ssh/ssh_host_ed25519_key <<'SECRETEOF'")
    expect(script).toContain("cat > /etc/ssh/ssh_host_ed25519_key.pub <<'SECRETEOF'\nssh-ed25519 BBBB...\nSECRETEOF")
    expect(script).toContain("cat > /root/.ssh/cache-key <<'SECRETEOF'")
    expect(script).toContain("cat > /etc/ssh/cache-host-key.pub <<'SECRETEOF'\nssh-ed25519 CCCC...\nSECRETEOF")
    expect(script).toContain("cat > /run/niks3-auth-token <<'SECRETEOF'\nniks3-token-value\nSECRETEOF")
    expect(script).toContain("cat > /run/ccache-r2-access-key <<'SECRETEOF'\nr2-access-key\nSECRETEOF")
    expect(script).toContain("cat > /run/ccache-r2-secret-key <<'SECRETEOF'\nr2-secret-key\nSECRETEOF")
  })

  it("sets correct permissions on secret files", async () => {
    const script = await runInstallScript({
      name: "builder-1",
      authKey: "auth-key-123",
      builderType: "regular",
    })

    expect(script).toContain("chmod 0400 /run/hcloud-token")
    expect(script).toContain("chmod 0400 /run/headscale-authkey")
    expect(script).toContain("chmod 0444 /run/builder-name")
    expect(script).toContain("chmod 0600 /var/lib/remotebuild/.ssh/authorized_keys")
    expect(script).toContain("chown remotebuild:remotebuild /var/lib/remotebuild/.ssh/authorized_keys")
    expect(script).toContain("chmod 0600 /etc/ssh/ssh_host_ed25519_key")
    expect(script).toContain("chmod 0644 /etc/ssh/ssh_host_ed25519_key.pub")
    expect(script).toContain("chmod 0400 /run/niks3-auth-token")
  })

  it("does not include builder-override.conf for regular builders", async () => {
    const script = await runInstallScript({
      name: "builder-1",
      authKey: "auth-key-123",
      builderType: "regular",
    })
    expect(script).not.toContain("builder-override.conf")
  })

  it("includes builder-override.conf for big builders", async () => {
    const script = await runInstallScript({
      name: "big-builder-1",
      authKey: "auth-key-123",
      builderType: "big",
    })
    expect(script).toContain("cat > /etc/nix/builder-override.conf")
    expect(script).toContain("max-jobs = 1")
    expect(script).toContain("cores = 0")
    expect(script).toContain("chmod 0644 /etc/nix/builder-override.conf")
  })

  it("uses builder name in /run/builder-name", async () => {
    const script = await runInstallScript({
      name: "builder-42",
      authKey: "key",
      builderType: "regular",
    })
    expect(script).toContain("cat > /run/builder-name <<'SECRETEOF'\nbuilder-42\nSECRETEOF")
  })
})
