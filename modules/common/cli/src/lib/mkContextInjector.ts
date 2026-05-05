import { Effect, Context } from "effect"

const extractFrame = (err: Error, index: number) => {
  const lines = err.stack?.trim().split("\n")
  if (!lines || lines.length <= index) return ""
  let frame = lines[index]!.trim()
  if (!frame.includes("(")) {
    frame = frame.replace(/at (.*)/, "at ($1)")
  }
  return frame
}

/**
 * Create an `inject` function that provides a context to service method implementations.
 *
 * Given a pre-built `Context` and a service name, returns a function that takes
 * a service method (a function returning an Effect) and returns a new function
 * with the same signature but with the context's services already provided.
 *
 * Each injected method is wrapped with `Effect.withSpan` using the method's
 * `fn.name` and a custom `captureStackTrace` that shows both the wiring site
 * and the actual call site.
 *
 * @example
 * ```ts
 * const inject = mkContextInjector(ctx, "Git")
 * return { repoRoot: inject(repoRoot) }
 * ```
 */
export function mkContextInjector<R2>(ctx: Context.Context<R2>, serviceName: string) {
  const provide = Effect.provide(ctx)

  return <Args extends readonly unknown[], A, E, R>(
    fn: (...args: Args) => Effect.Effect<A, E, R>,
  ) => {
    const spanName = `${serviceName}.${fn.name}`

    // Capture wiring site: the caller of inject() — i.e. the line in the service file
    const limit = Error.stackTraceLimit
    Error.stackTraceLimit = 3
    const errDef = new Error()
    Error.stackTraceLimit = limit

    return (...args: Args) => {
      // Capture call site: the caller of the wrapper — i.e. the handler
      const prevLimit = Error.stackTraceLimit
      Error.stackTraceLimit = 3
      const errCall = new Error()
      Error.stackTraceLimit = prevLimit

      const captureStackTrace = () =>
        `${extractFrame(errDef, 2)}\n${extractFrame(errCall, 2)}`

      return provide(fn(...args)).pipe(
        Effect.withSpan(spanName, { captureStackTrace }),
      )
    }
  }
}
