import { sql, type Kysely } from "kysely"

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Kysely migrations use untyped DB
export async function up(db: Kysely<any>): Promise<void> {
  // 1. Recreate mux_projects without tmux_session
  await db.schema.createTable("mux_projects_new")
    .addColumn("id", "integer", (cb) => cb.primaryKey().autoIncrement())
    .addColumn("path", "text", (cb) => cb.notNull().unique())
    .execute()

  await sql`
    INSERT INTO mux_projects_new (id, path)
    SELECT id, path FROM mux_projects
  `.execute(db)

  await db.schema.dropTable("mux_projects").execute()
  await sql`ALTER TABLE mux_projects_new RENAME TO mux_projects`.execute(db)

  // 2. Recreate mux_worktrees without tmux_window
  await db.schema.createTable("mux_worktrees_new")
    .addColumn("id", "integer", (cb) => cb.primaryKey().autoIncrement())
    .addColumn("project_id", "integer", (cb) =>
      cb.notNull().references("mux_projects.id").onDelete("cascade")
    )
    .addColumn("branch", "text", (cb) => cb.notNull())
    .addUniqueConstraint("uq_mux_worktrees_project_branch", ["project_id", "branch"])
    .execute()

  await sql`
    INSERT INTO mux_worktrees_new (id, project_id, branch)
    SELECT id, project_id, branch FROM mux_worktrees
  `.execute(db)

  await db.schema.dropTable("mux_worktrees").execute()
  await sql`ALTER TABLE mux_worktrees_new RENAME TO mux_worktrees`.execute(db)
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Kysely migrations use untyped DB
export async function down(db: Kysely<any>): Promise<void> {
  // Restore mux_projects with tmux_session
  await db.schema.createTable("mux_projects_new")
    .addColumn("id", "integer", (cb) => cb.primaryKey().autoIncrement())
    .addColumn("tmux_session", "text", (cb) => cb.notNull())
    .addColumn("path", "text", (cb) => cb.notNull().unique())
    .execute()

  await sql`
    INSERT INTO mux_projects_new (id, tmux_session, path)
    SELECT id, 'unknown', path FROM mux_projects
  `.execute(db)

  await db.schema.dropTable("mux_projects").execute()
  await sql`ALTER TABLE mux_projects_new RENAME TO mux_projects`.execute(db)

  // Restore mux_worktrees with tmux_window
  await db.schema.createTable("mux_worktrees_new")
    .addColumn("id", "integer", (cb) => cb.primaryKey().autoIncrement())
    .addColumn("project_id", "integer", (cb) =>
      cb.notNull().references("mux_projects.id").onDelete("cascade")
    )
    .addColumn("branch", "text", (cb) => cb.notNull())
    .addColumn("tmux_window", "text")
    .addUniqueConstraint("uq_mux_worktrees_project_branch", ["project_id", "branch"])
    .execute()

  await sql`
    INSERT INTO mux_worktrees_new (id, project_id, branch, tmux_window)
    SELECT id, project_id, branch, NULL FROM mux_worktrees
  `.execute(db)

  await db.schema.dropTable("mux_worktrees").execute()
  await sql`ALTER TABLE mux_worktrees_new RENAME TO mux_worktrees`.execute(db)
}
