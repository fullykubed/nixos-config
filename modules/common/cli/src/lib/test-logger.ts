import { Logger } from "effect"

/** A layer that silences all Effect.log output in tests. */
export const SilentLogger = Logger.replace(Logger.defaultLogger, Logger.none)

export const makeTestLogger = () => {
  const messages: string[] = []
  const layer = Logger.replace(
    Logger.defaultLogger,
    Logger.make(({ message }) => {
      messages.push(String(message))
    })
  )
  return { messages, layer }
}
