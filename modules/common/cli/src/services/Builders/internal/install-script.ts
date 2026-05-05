import { Effect } from "effect"
import type { FileSystem } from "@effect/platform"
import { SECRET_PATHS } from "./helpers"

const writeFile = (path: string, content: string, mode: string, owner: string) =>
  `cat > ${path} <<'SECRETEOF'
${content}
SECRETEOF
chmod ${mode} ${path}
chown ${owner} ${path}
`

export const createInstallScript = (fs: FileSystem.FileSystem, opts: {
  readonly name: string
  readonly authKey: string
  readonly builderType: "regular" | "big"
}) =>
  Effect.gen(function* () {
    const rawSecrets = yield* Effect.all({
      pubkey: fs.readFileString(SECRET_PATHS.pubkey),
      hostKey: fs.readFileString(SECRET_PATHS.hostKey),
      hostPubkey: fs.readFileString(SECRET_PATHS.hostPubkey),
      cacheSshKey: fs.readFileString(SECRET_PATHS.cacheSshKey),
      cacheHostPubkey: fs.readFileString(SECRET_PATHS.cacheHostPubkey),
      niks3Token: fs.readFileString(SECRET_PATHS.niks3Token),
      ccacheR2AccessKey: fs.readFileString(SECRET_PATHS.ccacheR2AccessKey),
      ccacheR2SecretKey: fs.readFileString(SECRET_PATHS.ccacheR2SecretKey),
      hcloudToken: fs.readFileString("/run/agenix/hetzner-api-token")
    }, { concurrency: "unbounded" })

    const secrets = {
      pubkey: rawSecrets.pubkey.trim(),
      hostKey: rawSecrets.hostKey.trim(),
      hostPubkey: rawSecrets.hostPubkey.trim(),
      cacheSshKey: rawSecrets.cacheSshKey.trim(),
      cacheHostPubkey: rawSecrets.cacheHostPubkey.trim(),
      niks3Token: rawSecrets.niks3Token.trim(),
      ccacheR2AccessKey: rawSecrets.ccacheR2AccessKey.trim(),
      ccacheR2SecretKey: rawSecrets.ccacheR2SecretKey.trim(),
      hcloudToken: rawSecrets.hcloudToken.trim(),
    }

    let script = `#!/usr/bin/env bash
set -euo pipefail

mkdir -p /var/lib/remotebuild/.ssh /root/.ssh /etc/ssh /etc/nix

`
    script += writeFile("/run/hcloud-token", secrets.hcloudToken, "0400", "root:root")
    script += "\n"
    script += writeFile("/run/headscale-authkey", opts.authKey, "0400", "root:root")
    script += "\n"
    script += writeFile("/run/builder-name", opts.name, "0444", "root:root")
    script += "\n"
    script += writeFile("/var/lib/remotebuild/.ssh/authorized_keys", secrets.pubkey, "0600", "remotebuild:remotebuild")
    script += "\n"
    script += writeFile("/root/.ssh/authorized_keys", secrets.pubkey, "0600", "root:root")
    script += "\n"
    script += writeFile("/etc/ssh/ssh_host_ed25519_key", secrets.hostKey, "0600", "root:root")
    script += "\n"
    script += writeFile("/etc/ssh/ssh_host_ed25519_key.pub", secrets.hostPubkey, "0644", "root:root")
    script += "\n"
    script += writeFile("/root/.ssh/cache-key", secrets.cacheSshKey, "0600", "root:root")
    script += "\n"
    script += writeFile("/etc/ssh/cache-host-key.pub", secrets.cacheHostPubkey, "0644", "root:root")
    script += "\n"
    script += writeFile("/run/niks3-auth-token", secrets.niks3Token, "0400", "root:root")
    script += "\n"
    script += writeFile("/run/ccache-r2-access-key", secrets.ccacheR2AccessKey, "0400", "root:root")
    script += "\n"
    script += writeFile("/run/ccache-r2-secret-key", secrets.ccacheR2SecretKey, "0400", "root:root")

    if (opts.builderType === "big") {
      script += "\n"
      script += writeFile("/etc/nix/builder-override.conf", "max-jobs = 1\ncores = 0", "0644", "root:root")
    }

    return script
  })
