import { Logger } from "effect"

// eslint-disable-next-line @typescript-eslint/no-empty-function
const silentLogger = Logger.make(() => {})

/** Layer that suppresses all log output — use in tests that don't inspect messages. */
export const SilentLogger = Logger.replace(Logger.defaultLogger, silentLogger)

/** Creates a test logger that captures messages into an array. */
export const makeTestLogger = () => {
  const messages: string[] = []
  const logger = Logger.make(({ message }) => {
    messages.push(typeof message === "string" ? message : String(message))
  })
  const layer = Logger.replace(Logger.defaultLogger, logger)
  return { messages, layer }
}
