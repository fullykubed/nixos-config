import { sql, type Kysely } from "kysely"

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Kysely migrations use untyped DB
export async function up(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable("mux_worktrees")
    .addColumn("created_at", "text", (cb) =>
      cb.notNull().defaultTo(sql`(strftime('%Y-%m-%dT%H:%M:%fZ','now'))`)
    )
    .execute()
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Kysely migrations use untyped DB
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.alterTable("mux_worktrees")
    .dropColumn("created_at")
    .execute()
}
