import { Effect } from "effect"
import type { SshService } from "../../../services/Ssh"
import type { ShellService } from "../../../services/Shell"


export const checkNetworkPerformance = (_ip: string, _ssh: SshService["Type"], _shell: ShellService["Type"]) =>
  Effect.succeed({
    name: "Network performance",
    status: "SKIPPED" as const,
    details: "Not yet implemented"
  })
