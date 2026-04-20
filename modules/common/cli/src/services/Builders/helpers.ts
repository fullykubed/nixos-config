import { BUILDER_CONFIG } from "./config"

export const SECRET_PATHS = {
  pubkey: "/etc/ssh/builder-key.pub",
  hostKey: "/run/agenix/builder-host-key",
  hostPubkey: "/etc/ssh/builder-host-key.pub",
  cacheSshKey: "/root/.ssh/cache-key",
  cacheHostPubkey: "/etc/ssh/cache-host-key.pub",
  niks3Token: "/run/agenix/niks3-api-token",
  ccacheR2AccessKey: "/run/agenix/ccache-r2-access-key",
  ccacheR2SecretKey: "/run/agenix/ccache-r2-secret-key",
  headscaleApiKey: "/run/agenix/headscale-api-key",
} as const

/**
 * Normalize builder name input.
 * - Bare numbers become "builder-N" (e.g., "1" -> "builder-1")
 * - "big-N" becomes "big-builder-N" (e.g., "big-1" -> "big-builder-1")
 * - Full names pass through unchanged
 */
export const normalizeName = (input: string): string => {
  // Handle bare numbers: "1" -> "builder-1"
  if (/^\d+$/.test(input)) {
    return `builder-${input}`
  }

  // Handle "big-N" pattern: "big-1" -> "big-builder-1"
  const bigMatch = /^big-(\d+)$/.exec(input)
  if (bigMatch) {
    return `big-builder-${bigMatch[1]}`
  }

  // Pass through full names unchanged
  return input
}

/**
 * Check if a name matches the valid builder name pattern
 */
export const isBuilderName = (name: string): boolean => {
  return BUILDER_CONFIG.builderPattern.test(name)
}

/**
 * Determine builder type from name: "regular" or "big"
 */
export const builderType = (name: string): "regular" | "big" => {
  return name.startsWith("big-builder-") ? "big" : "regular"
}

/**
 * Get server type for a builder name
 */
export const serverTypeFor = (name: string): string => {
  return builderType(name) === "big"
    ? BUILDER_CONFIG.bigServerType
    : BUILDER_CONFIG.regularServerType
}