import type { Kysely } from "kysely"

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Kysely migrations use untyped DB
export async function up(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable("mux_worktrees")
    .addColumn("deleted_at", "text")
    .execute()
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Kysely migrations use untyped DB
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable("mux_worktrees")
    .dropColumn("deleted_at")
    .execute()
}
