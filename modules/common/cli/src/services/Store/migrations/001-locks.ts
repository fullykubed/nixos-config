import { sql, type Kysely } from "kysely"
import type { DB } from "../types"

export async function up(db: Kysely<DB>): Promise<void> {
  await db.schema.createTable("locks")
    .addColumn("name", "text", (cb) => cb.primaryKey())
    .addColumn("pid", "integer", (cb) => cb.notNull())
    .addColumn("acquired_at", "text", (cb) =>
      cb.notNull().defaultTo(sql`(strftime('%Y-%m-%dT%H:%M:%fZ','now'))`)
    )
    .execute()
}

export async function down(db: Kysely<DB>): Promise<void> {
  await db.schema.dropTable("locks").execute()
}
