import type { Generated } from "kysely"

interface LocksTable {
  name: string
  pid: number
  acquired_at: Generated<string>
}

export interface DB {
  locks: LocksTable
}
