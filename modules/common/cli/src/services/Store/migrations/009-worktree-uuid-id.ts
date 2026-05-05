import { sql, type Kysely } from "kysely"

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Kysely migrations use untyped DB
export async function up(db: Kysely<any>): Promise<void> {
  // Recreate mux_worktrees with text id (UUID) instead of integer autoincrement
  await db.schema.createTable("mux_worktrees_new")
    .addColumn("id", "text", (cb) => cb.primaryKey())
    .addColumn("project_id", "text", (cb) =>
      cb.notNull().references("mux_projects.id").onDelete("cascade")
    )
    .addColumn("branch", "text", (cb) => cb.notNull())
    .addColumn("created_at", "text", (cb) => cb.notNull().defaultTo(sql`(datetime('now'))`))
    .addColumn("deleted_at", "text")
    .execute()

  await sql`
    INSERT INTO mux_worktrees_new (id, project_id, branch, created_at, deleted_at)
    SELECT CAST(id AS TEXT), project_id, branch, created_at, deleted_at FROM mux_worktrees
  `.execute(db)

  await db.schema.dropTable("mux_worktrees").execute()
  await sql`ALTER TABLE mux_worktrees_new RENAME TO mux_worktrees`.execute(db)
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Kysely migrations use untyped DB
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.createTable("mux_worktrees_new")
    .addColumn("id", "integer", (cb) => cb.primaryKey().autoIncrement())
    .addColumn("project_id", "text", (cb) =>
      cb.notNull().references("mux_projects.id").onDelete("cascade")
    )
    .addColumn("branch", "text", (cb) => cb.notNull())
    .addColumn("created_at", "text", (cb) => cb.notNull().defaultTo(sql`(datetime('now'))`))
    .addColumn("deleted_at", "text")
    .execute()

  await sql`
    INSERT INTO mux_worktrees_new (id, project_id, branch, created_at, deleted_at)
    SELECT CAST(id AS INTEGER), project_id, branch, created_at, deleted_at FROM mux_worktrees
  `.execute(db)

  await db.schema.dropTable("mux_worktrees").execute()
  await sql`ALTER TABLE mux_worktrees_new RENAME TO mux_worktrees`.execute(db)
}
