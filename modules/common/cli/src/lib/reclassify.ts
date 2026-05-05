const spanSymbol = Symbol.for("effect/SpanAnnotation")

/**
 * Reclassify an error using a classifier function, preserving the original
 * error's JS stack trace and Effect span annotation on the result.
 *
 * Suppresses stack capture during classification for performance.
 */
export const reclassify = <S extends Error, T extends Error>(source: S, classify: (e: S) => T): T => {
  const prevLimit = Error.stackTraceLimit
  Error.stackTraceLimit = 0
  const target = classify(source)
  Error.stackTraceLimit = prevLimit
  target.stack = source.stack
  if (spanSymbol in source) {
    (target as Record<symbol, unknown>)[spanSymbol] = (source as Record<symbol, unknown>)[spanSymbol]
  }
  return target
}
