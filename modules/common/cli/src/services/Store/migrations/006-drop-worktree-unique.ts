import { sql, type Kysely } from "kysely"

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Kysely migrations use untyped DB
export async function up(db: Kysely<any>): Promise<void> {
  await db.schema.createTable("mux_worktrees_new")
    .addColumn("id", "integer", (cb) => cb.primaryKey().autoIncrement())
    .addColumn("project_id", "integer", (cb) =>
      cb.notNull().references("mux_projects.id").onDelete("cascade")
    )
    .addColumn("branch", "text", (cb) => cb.notNull())
    .addColumn("created_at", "text", (cb) =>
      cb.notNull().defaultTo(sql`(strftime('%Y-%m-%dT%H:%M:%fZ','now'))`)
    )
    .execute()

  await sql`
    INSERT INTO mux_worktrees_new (id, project_id, branch, created_at)
    SELECT id, project_id, branch, created_at FROM mux_worktrees
  `.execute(db)

  await db.schema.dropTable("mux_worktrees").execute()
  await sql`ALTER TABLE mux_worktrees_new RENAME TO mux_worktrees`.execute(db)
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Kysely migrations use untyped DB
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.createTable("mux_worktrees_new")
    .addColumn("id", "integer", (cb) => cb.primaryKey().autoIncrement())
    .addColumn("project_id", "integer", (cb) =>
      cb.notNull().references("mux_projects.id").onDelete("cascade")
    )
    .addColumn("branch", "text", (cb) => cb.notNull())
    .addColumn("created_at", "text", (cb) =>
      cb.notNull().defaultTo(sql`(strftime('%Y-%m-%dT%H:%M:%fZ','now'))`)
    )
    .addUniqueConstraint("uq_mux_worktrees_project_branch", ["project_id", "branch"])
    .execute()

  await sql`
    INSERT INTO mux_worktrees_new (id, project_id, branch, created_at)
    SELECT id, project_id, branch, created_at FROM mux_worktrees
  `.execute(db)

  await db.schema.dropTable("mux_worktrees").execute()
  await sql`ALTER TABLE mux_worktrees_new RENAME TO mux_worktrees`.execute(db)
}
