import { Logger, LogLevel } from "effect"

const RED = Bun.color("red", "ansi")
const YELLOW = Bun.color("yellow", "ansi")
const RESET = "\x1b[0m"

const colorize = (text: string, color: string | null): string =>
  process.stderr.isTTY && color ? `${color}${text}${RESET}` : text

/**
 * CLI-friendly logger: info → stdout plain, warning → stderr yellow, error → stderr red.
 * No timestamps, fiber IDs, or other metadata — just the message.
 */
const cliLogger = Logger.make(({ logLevel, message }) => {
  const text = typeof message === "string" ? message : String(message)

  if (LogLevel.greaterThanEqual(logLevel, LogLevel.Error)) {
    process.stderr.write(colorize(text, RED) + "\n")
  } else if (LogLevel.greaterThanEqual(logLevel, LogLevel.Warning)) {
    process.stderr.write(colorize(text, YELLOW) + "\n")
  } else {
    process.stdout.write(text + "\n")
  }
})

export const CliLoggerLive = Logger.replace(Logger.defaultLogger, cliLogger)
