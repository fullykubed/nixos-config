import type { CheckResult } from "./handler"

const RESET = "\x1b[0m"
const colors = {
  OK: Bun.color("green", "ansi"),
  FAILED: Bun.color("red", "ansi"),
  SKIPPED: Bun.color("yellow", "ansi"),
  WARNING: Bun.color("yellow", "ansi"),
}

export const colorize = (text: string, status: CheckResult["status"]): string => {
  const color = colors[status]
  if (!process.stdout.isTTY || !color) return text
  return `${color}${text}${RESET}`
}
