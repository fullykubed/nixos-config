import { Effect, Tracer, Option } from "effect"
import type { Span, AnySpan, SpanLink } from "effect/Tracer"

interface CollectedSpan {
  name: string
  spanId: string
  parentId: string | undefined
  startTime: bigint
  endTime: bigint | undefined
  status: "ok" | "error" | "running"
  children: CollectedSpan[]
}

const collected: CollectedSpan[] = []
const byId = new Map<string, CollectedSpan>()

const parentSpanId = (parent: Option.Option<AnySpan>): string | undefined => {
  if (Option.isNone(parent)) return undefined
  return parent.value.spanId
}

const tracer = Tracer.make({
  span: (name, parent, context, links, startTime, kind) => {
    const attrs = new Map<string, unknown>()
    const spanLinks: SpanLink[] = Array.from(links)

    const span: Span = {
      _tag: "Span",
      name,
      spanId: Math.random().toString(36).slice(2, 10),
      traceId: Option.isSome(parent) ? parent.value.traceId : Math.random().toString(36).slice(2, 18),
      parent,
      context,
      links: spanLinks as readonly SpanLink[],
      sampled: true,
      kind,
      status: { _tag: "Started", startTime },
      attributes: attrs as ReadonlyMap<string, unknown>,
      end(endTime, exit) {
        ;(this as { status: Span["status"] }).status = { _tag: "Ended", endTime, exit, startTime }
        const entry = byId.get(this.spanId)
        if (entry) {
          entry.endTime = endTime
          entry.status = exit._tag === "Success" ? "ok" : "error"
        }
      },
      attribute(key, value) {
        attrs.set(key, value)
      },
      event(_name, _startTime, _attributes) {
        // no-op for trace collection
      },
      addLinks(newLinks) {
        spanLinks.push(...newLinks)
      },
    }

    const entry: CollectedSpan = {
      name,
      spanId: span.spanId,
      parentId: parentSpanId(parent),
      startTime,
      endTime: undefined,
      status: "running",
      children: [],
    }
    byId.set(span.spanId, entry)

    const pid = entry.parentId
    if (pid && byId.has(pid)) {
      byId.get(pid)!.children.push(entry)
    } else {
      collected.push(entry)
    }

    return span
  },
  context: (f) => f(),
})

const renderTree = (spans: CollectedSpan[], indent = ""): string => {
  const lines: string[] = []
  for (let i = 0; i < spans.length; i++) {
    const s = spans[i]!
    const isLast = i === spans.length - 1
    const prefix = indent + (isLast ? "└─ " : "├─ ")
    const childIndent = indent + (isLast ? "   " : "│  ")
    const marker = s.status === "error" ? "✗" : s.status === "ok" ? "✓" : "…"
    const duration = s.endTime != null
      ? ` (${Math.round(Number(s.endTime - s.startTime) / 100_000) / 10}ms)`
      : ""
    lines.push(`${prefix}${marker} ${s.name}${duration}`)
    if (s.children.length > 0) {
      lines.push(renderTree(s.children, childIndent))
    }
  }
  return lines.join("\n")
}

export const printTrace = (): void => {
  if (collected.length === 0) return
  process.stderr.write(`\n── Span trace ──\n${renderTree(collected)}\n`)
}

export const withTraceTracer = <A, E, R>(
  effect: Effect.Effect<A, E, R>,
) =>
  Effect.withTracer(effect, tracer)
