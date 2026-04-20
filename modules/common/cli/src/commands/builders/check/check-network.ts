import { Effect } from "effect"
import type { SshService } from "../../../services/Ssh"
import type { ShellService } from "../../../services/Shell"
import type { CheckResult } from "./handler"

export const checkNetworkPerformance = (_ip: string, _ssh: SshService["Type"], _shell: ShellService["Type"]): Effect.Effect<CheckResult> =>
  Effect.succeed({
    name: "Network performance",
    status: "SKIPPED" as const,
    details: "Not yet implemented"
  })
