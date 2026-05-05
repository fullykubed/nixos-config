#!/usr/bin/env bun

import { Cause, Effect, Exit, Fiber } from "effect"
import { parse } from "./cli/parser"
import { topLevelHelp, groupHelp, commandHelp } from "./cli/help"
import { registry } from "./cli/registry"
import { CliLoggerLive } from "./lib/logger"


const program = Effect.gen(function* () {
  const parsed = yield* parse(registry, process.argv)

  // Handle help commands
  if (parsed.command === "help") {
    if (parsed.group === "") {
      yield* Effect.log(topLevelHelp(registry))
    } else {
      const group = registry.groups.get(parsed.group)
      if (group) {
        yield* Effect.log(groupHelp(group))
      }
    }
    return
  }

  // Look up command
  const group = registry.groups.get(parsed.group)!
  const command = group.commands.get(parsed.command)!

  // Show command-level help when --help / -h is passed
  if (parsed.flags.help === true) {
    yield* Effect.log(commandHelp(group, command))
    return
  }

  yield* command.handler(parsed)
})

// Format tagged errors with user-friendly messages
const s = (v: unknown): string => {
  if (v == null) return ""
  if (typeof v === "object") return JSON.stringify(v)
  return String(v as string | number | boolean)
}

/** Safe property access on tagged error objects — avoids Record<string, unknown> cast. */
const f = (e: object, key: string): unknown => Reflect.get(e, key)

const formatTaggedError = (e: object & { readonly _tag: string }): string => {
  switch (e._tag) {
    case "UnknownCommand": {
      const available = f(e, "available")
      return `Unknown command: ${s(f(e, "input"))}${
        Array.isArray(available) && available.length > 0
          ? `\nAvailable: ${(available as string[]).join(", ")}`
          : ""
      }`
    }
    case "UnknownFlag":
      return `Unknown flag: ${s(f(e, "flag"))} (command: ${s(f(e, "command"))})`
    case "MissingArgument":
      return `Missing required argument: ${s(f(e, "name"))} (command: ${s(f(e, "command"))})`
    case "InvalidValue":
      return `Invalid value '${s(f(e, "value"))}' for --${s(f(e, "flag"))}. Expected: ${s(f(e, "expected"))}`
    case "ValidationErrors": {
      const errors = f(e, "errors") as { flag: string; value: string; expected: string }[]
      return errors.map((err) =>
        `Invalid value '${err.value}' for --${err.flag}. Expected: ${err.expected}`
      ).join("\n")
    }
    case "ParseError":
      return `Parse error: ${s(f(e, "message"))}`
    case "ShellError":
      return `Command failed: ${s(f(e, "command"))}${f(e, "stderr") ? `\n${s(f(e, "stderr"))}` : ""}`
    case "HcloudServerNotFound":
      return `Server not found: ${s(f(e, "name"))}`
    case "HcloudImageNotFound":
      return `Image not found: ${s(f(e, "id"))}`
    case "HcloudVolumeNotFound":
      return `Volume not found: ${s(f(e, "name"))}`
    case "HcloudListServersError":
      return `Failed to list servers: ${s(f(e, "message"))}`
    case "HcloudGetServerError":
      return `Failed to get server ${s(f(e, "name"))}: ${s(f(e, "message"))}`
    case "HcloudCreateServerError":
      return `Failed to create server ${s(f(e, "name"))}: ${s(f(e, "message"))}`
    case "HcloudDeleteServerError":
      return `Failed to delete server ${s(f(e, "name"))}: ${s(f(e, "message"))}`
    case "HcloudGetImageError":
      return `Failed to get image ${s(f(e, "id"))}: ${s(f(e, "message"))}`
    case "HcloudListImagesError":
      return `Failed to list images: ${s(f(e, "message"))}`
    case "HcloudDeleteImageError":
      return `Failed to delete image ${s(f(e, "id"))}: ${s(f(e, "message"))}`
    case "HcloudGetVolumeError":
      return `Failed to get volume ${s(f(e, "name"))}: ${s(f(e, "message"))}`
    case "HcloudListVolumesError":
      return `Failed to list volumes: ${s(f(e, "message"))}`
    case "HcloudCreateVolumeError":
      return `Failed to create volume ${s(f(e, "name"))}: ${s(f(e, "message"))}`
    case "HcloudDeleteVolumeError":
      return `Failed to delete volume ${s(f(e, "name"))}: ${s(f(e, "message"))}`
    case "HcloudDetachVolumeError":
      return `Failed to detach volume ${s(f(e, "name"))}: ${s(f(e, "message"))}`
    case "TailscaleNotConnectedError":
      return `Tailscale not connected: ${s(f(e, "message"))}`
    case "SshConnectionError":
      return `SSH connection failed to ${s(f(e, "host"))}: ${s(f(e, "stderr"))}`
    case "SshAuthError":
      return `SSH authentication failed to ${s(f(e, "host"))}`
    case "SshTimeoutError":
      return `SSH timeout to ${s(f(e, "host"))} after ${s(f(e, "timeout"))}s`
    case "SshHostKeyError":
      return `SSH host key verification failed for ${s(f(e, "host"))}`
    case "HeadscalePreAuthError":
      return `Headscale pre-auth key error: ${s(f(e, "message"))}`
    case "HeadscaleNodeError":
      return `Headscale node error (${s(f(e, "hostname"))}): ${s(f(e, "message"))}`
    case "InvalidBuilderNameError":
      return `Invalid builder name: ${s(f(e, "input"))}. Use N, builder-N, or big-builder-N`
    case "BuilderNotFoundError":
      return `Builder not found: ${s(f(e, "name"))}`
    case "BuilderUnreachableError":
      return `Builder unreachable (${s(f(e, "name"))}): ${s(f(e, "reason"))}`
    case "BuilderDestroyError":
      return `Failed to destroy builder ${s(f(e, "name"))}: ${s(f(e, "message"))}`
    case "BuilderCreateError":
      return `Failed to create builder ${s(f(e, "name"))}: ${s(f(e, "message"))}`
    case "CrocRelayUnreachableError":
      return `Croc relay not reachable at ${s(f(e, "relayAddress"))}`
    case "CrocRelayPassError":
      return `Croc relay password error: ${s(f(e, "message"))}`
    case "CrocCodeError":
      return `Croc code generation error: ${s(f(e, "message"))}`
    case "CrocSendError":
      return `Croc send failed: ${s(f(e, "message"))}`
    case "JsonParseError":
      return `JSON parse error from ${s(f(e, "command"))}: ${s(f(e, "error"))}`
    case "StoreError":
      return `Store error (${s(f(e, "operation"))}): ${s(f(e, "message"))}\n  path: ${s(f(e, "path"))}`
    case "LockAcquireError":
      return `Failed to acquire lock "${s(f(e, "name"))}": ${s(f(e, "message"))}`
    case "LockReleaseError":
      return `Failed to release lock "${s(f(e, "name"))}": ${s(f(e, "message"))}`
    case "NotInsideTmuxError":
      return `Not inside tmux: ${s(f(e, "message"))}`
    case "TmuxWindowNotFoundError":
      return `Tmux window not found: ${s(f(e, "name"))}`
    case "TmuxPaneNotFoundError":
      return `Tmux pane not found: ${s(f(e, "pane"))}`
    case "TmuxSessionNotFoundError":
      return `Tmux session not found: ${s(f(e, "session"))}`
    case "TmuxNotRunningError":
      return `Tmux server is not running`
    case "TmuxCommandError":
      return `Tmux error (${s(f(e, "operation"))}): ${s(f(e, "message"))}`
    case "GitNotRepoError":
      return `Not a git repository: ${s(f(e, "message"))}`
    case "GitRepoDoesNotExistError":
      return `Remote repository not found: ${s(f(e, "message"))}`
    case "GitRefDoesNotExistError":
      return `Git ref does not exist: ${s(f(e, "message"))}`
    case "GitRemoteDoesNotExistError":
      return `Git remote not configured: ${s(f(e, "message"))}`
    case "GitAuthError":
      return `Git authentication failed: ${s(f(e, "message"))}`
    case "GitConnectivityError":
      return `Git network error: ${s(f(e, "message"))}`
    case "GitUnknownError":
      return `Git error: ${s(f(e, "message"))}`
    case "ProjectConfigParseError":
      return `Invalid project.json at ${s(f(e, "path"))}: ${s(f(e, "message"))}`
    case "MuxStoreError":
      return `Store error (${s(f(e, "operation"))}): ${s(f(e, "message"))}`
    default:
      return `${e._tag}: ${JSON.stringify(e)}`
  }
}

const formatError = (e: unknown): string =>
  typeof e === "string"
    ? e
    : typeof e === "object" && e !== null && "_tag" in e
      ? formatTaggedError(e as object & { _tag: string })
      : e instanceof Error
        ? e.message
        : String(e)

const main = program.pipe(
  Effect.catchAll((e) =>
    Effect.logError(formatError(e)).pipe(Effect.as(1))
  ),
  Effect.provide(CliLoggerLive),
  Effect.as(0)
)

const fiber = Effect.runFork(main)

for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.on(signal, () => Effect.runFork(Fiber.interrupt(fiber)))
}

void Effect.runPromise(Fiber.await(fiber)).then((exit) => {
  if (Exit.isSuccess(exit)) process.exit(exit.value)
  if (Cause.isInterruptedOnly(exit.cause)) process.exit(130)
  process.stderr.write(`Fatal: ${Cause.pretty(exit.cause)}\n`)
  process.exit(1)
})
