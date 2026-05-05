import { StoreError } from "../../Store"

export const isProcessAlive = (pid: number): boolean => {
  const result = Bun.spawnSync(["kill", "-0", String(pid)])
  return result.exitCode === 0
}

export const toStoreError = (e: unknown): StoreError => new StoreError({
  operation: "lock",
  message: e instanceof Error ? e.message : String(e),
})