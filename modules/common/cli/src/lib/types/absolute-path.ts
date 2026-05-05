import { Brand } from "effect"

export type AbsolutePath = string & Brand.Brand<"AbsolutePath">

export const isAbsolutePath = (s: string): s is AbsolutePath =>
  s.startsWith("/")

export const AbsolutePath = Brand.refined<AbsolutePath>(
  isAbsolutePath,
  () => Brand.error("an absolute path (must start with /)")
)
