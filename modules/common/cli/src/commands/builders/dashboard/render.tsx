/* eslint-disable @typescript-eslint/no-unsafe-return, @typescript-eslint/no-unsafe-assignment -- OpenTUI JSX types resolve to any */
import { createSignal, createMemo, onCleanup, Show, For } from "solid-js"
import { useKeyboard, useRenderer } from "@opentui/solid"
import { BUILDER_CONFIG, builderType, type BuilderStats } from "../../../services/Builders"
import { formatMemory } from "./format-memory"
import { getHealthColor } from "./get-health-color"

interface DashboardProps {
  fetchStats: () => Promise<BuilderStats[]>
}

const healthFg: Record<string, string> = {
  red: "red",
  yellow: "yellow",
  green: "green",
}

function formatRow(builder: BuilderStats): string {
  const name = builder.name.padEnd(16)

  const cpu = builder.reachable
    ? `${builder.cpuPercent}%`.padStart(6)
    : "---".padStart(6)

  let mem: string
  if (builder.reachable && builder.memTotalKb > 0) {
    const pct = Math.round((builder.memUsedKb / builder.memTotalKb) * 100)
    mem = `${formatMemory(builder.memUsedKb)}/${formatMemory(builder.memTotalKb)} (${pct}%)`.padStart(12)
  } else {
    mem = "---".padStart(12)
  }

  const disk = builder.reachable
    ? `${builder.diskPercent}%`.padStart(8)
    : "---".padStart(8)

  const builds = `${builder.builds}`.padStart(8)

  const idle = builder.reachable
    ? `${builder.idleCount}`.padStart(6)
    : "---".padStart(6)

  let tsText: string
  if (builder.tailscaleStatus === "up") tsText = "UP"
  else if (builder.tailscaleStatus === "down") tsText = "DOWN"
  else tsText = builder.tailscaleStatus.toUpperCase()
  const ts = tsText.padStart(8)

  let ccacheText: string
  if (!builder.reachable) ccacheText = "---"
  else if (!builder.ccacheMount || !builder.ccacheSync) ccacheText = "WARN"
  else ccacheText = "OK"
  const ccache = ccacheText.padStart(10)

  let statusText: string
  if (!builder.reachable) statusText = "UNREACHABLE"
  else if (builder.cpuPercent > 80 || (builder.memTotalKb > 0 && (builder.memUsedKb / builder.memTotalKb) > 0.9)) statusText = "HIGH LOAD"
  else if (!builder.ccacheMount || !builder.ccacheSync) statusText = "DEGRADED"
  else statusText = "HEALTHY"
  const status = statusText.padStart(12)

  return `${name}${cpu}${mem}${disk}${builds}${idle}${ts}${ccache}${status}`
}

const headerText = `${"NAME".padEnd(16)}${"CPU%".padStart(6)}${"MEMORY".padStart(12)}${"DISK%".padStart(8)}${"BUILDS".padStart(8)}${"IDLE".padStart(6)}${"TS".padStart(8)}${"CCACHE".padStart(10)}${"STATUS".padStart(12)}`

const separator = "─".repeat(88)

export function Dashboard(props: DashboardProps) {
  const [stats, setStats] = createSignal<BuilderStats[]>([])
  const [lastRefresh, setLastRefresh] = createSignal(new Date())
  const renderer = useRenderer()

  const refresh = async () => {
    const result = await props.fetchStats()
    setStats(result)
    setLastRefresh(new Date())
  }

  useKeyboard((e) => {
    if (e.name === "q") renderer.destroy()
    else if (e.name === "r") void refresh()
  })

  void refresh()
  const interval = setInterval(() => void refresh(), 3000)
  onCleanup(() => { clearInterval(interval) })

  const summary = createMemo(() => {
    const s = stats()
    let totalCost = 0
    let totalBuilds = 0
    let reachableCount = 0
    for (const b of s) {
      const type = builderType(b.name)
      totalCost += type === "big" ? BUILDER_CONFIG.bigCostPerHour : BUILDER_CONFIG.regularCostPerHour
      if (b.reachable) {
        reachableCount++
        totalBuilds += b.builds
      }
    }
    return { totalCost, totalBuilds, reachableCount, total: s.length }
  })

  return (
    <box flexDirection="column" width="100%" height="100%">
      <text fg="cyan"><b>Builders Dashboard</b> - Last refresh: {lastRefresh().toLocaleTimeString()}</text>
      <text> </text>
      <Show
        when={stats().length > 0}
        fallback={
          <>
            <text fg="yellow">No builders currently running</text>
            <text> </text>
            <text fg="#888">Press 'q' to quit, 'r' to refresh</text>
          </>
        }
      >
        <text><b>{headerText}</b></text>
        <text>{separator}</text>
        <For each={stats()}>{(builder) =>
          <text fg={healthFg[getHealthColor(builder)]}>{formatRow(builder)}</text>
        }</For>
        <text>{separator}</text>
        <text><b>SUMMARY:</b> {summary().reachableCount}/{summary().total} builders online • {summary().totalBuilds} active builds • ${summary().totalCost.toFixed(4)}/hour total cost</text>
        <text> </text>
        <text fg="#888">Press 'q' to quit, 'r' to refresh</text>
      </Show>
    </box>
  )
}
