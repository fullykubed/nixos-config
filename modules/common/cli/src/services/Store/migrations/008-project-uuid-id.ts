import { sql, type Kysely } from "kysely"

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Kysely migrations use untyped DB
export async function up(db: Kysely<any>): Promise<void> {
  // 1. Recreate mux_projects with text id (UUID)
  await db.schema.createTable("mux_projects_new")
    .addColumn("id", "text", (cb) => cb.primaryKey())
    .addColumn("path", "text", (cb) => cb.notNull().unique())
    .execute()

  await sql`
    INSERT INTO mux_projects_new (id, path)
    SELECT CAST(id AS TEXT), path FROM mux_projects
  `.execute(db)

  await db.schema.dropTable("mux_projects").execute()
  await sql`ALTER TABLE mux_projects_new RENAME TO mux_projects`.execute(db)

  // 2. Recreate mux_worktrees with text project_id
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
    SELECT id, CAST(project_id AS TEXT), branch, created_at, deleted_at FROM mux_worktrees
  `.execute(db)

  await db.schema.dropTable("mux_worktrees").execute()
  await sql`ALTER TABLE mux_worktrees_new RENAME TO mux_worktrees`.execute(db)
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Kysely migrations use untyped DB
export async function down(db: Kysely<any>): Promise<void> {
  // Restore integer id for mux_projects
  await db.schema.createTable("mux_projects_new")
    .addColumn("id", "integer", (cb) => cb.primaryKey().autoIncrement())
    .addColumn("path", "text", (cb) => cb.notNull().unique())
    .execute()

  await sql`
    INSERT INTO mux_projects_new (id, path)
    SELECT CAST(id AS INTEGER), path FROM mux_projects
  `.execute(db)

  await db.schema.dropTable("mux_projects").execute()
  await sql`ALTER TABLE mux_projects_new RENAME TO mux_projects`.execute(db)

  // Restore integer project_id for mux_worktrees
  await db.schema.createTable("mux_worktrees_new")
    .addColumn("id", "integer", (cb) => cb.primaryKey().autoIncrement())
    .addColumn("project_id", "integer", (cb) =>
      cb.notNull().references("mux_projects.id").onDelete("cascade")
    )
    .addColumn("branch", "text", (cb) => cb.notNull())
    .addColumn("created_at", "text", (cb) => cb.notNull().defaultTo(sql`(datetime('now'))`))
    .addColumn("deleted_at", "text")
    .execute()

  await sql`
    INSERT INTO mux_worktrees_new (id, project_id, branch, created_at, deleted_at)
    SELECT id, CAST(project_id AS INTEGER), branch, created_at, deleted_at FROM mux_worktrees
  `.execute(db)

  await db.schema.dropTable("mux_worktrees").execute()
  await sql`ALTER TABLE mux_worktrees_new RENAME TO mux_worktrees`.execute(db)
}
