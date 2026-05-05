import { Effect, Context } from "effect"

/**
 * Create an `inject` function that provides a context to service method implementations.
 *
 * Given a pre-built `Context`, returns a function that takes a service method
 * (a function returning an Effect) and returns a new function with the same
 * signature but with the context's services already provided.
 *
 * @example
 * ```ts
 * const ctx = Context.empty().pipe(
 *   Context.add(ShellService, shell),
 *   Context.add(FileSystem.FileSystem, fs),
 * )
 * const inject = mkContextInjector(ctx)
 *
 * return {
 *   listServers: inject(listServers),
 *   getServer: inject(getServer),
 * }
 * ```
 */
export const mkContextInjector = <R2>(ctx: Context.Context<R2>) => {
  const provide = Effect.provide(ctx)

  return <Args extends readonly unknown[], A, E, R>(
    fn: (...args: Args) => Effect.Effect<A, E, R>
  ) => (...args: Args) => provide(fn(...args))
}
