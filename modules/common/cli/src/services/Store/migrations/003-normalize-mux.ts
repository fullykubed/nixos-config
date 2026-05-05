import { sql, type Kysely } from "kysely"

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Kysely migrations use untyped DB
export async function up(db: Kysely<any>): Promise<void> {
  // 1. Create mux_projects table
  await db.schema.createTable("mux_projects")
    .addColumn("id", "integer", (cb) => cb.primaryKey().autoIncrement())
    .addColumn("tmux_session", "text", (cb) => cb.notNull())
    .addColumn("path", "text", (cb) => cb.notNull().unique())
    .execute()

  // 2. Populate from distinct repo_root values
  await sql`
    INSERT OR IGNORE INTO mux_projects (tmux_session, path)
    SELECT COALESCE(tmux_session, 'unknown'), repo_root
    FROM mux_worktrees
    GROUP BY repo_root
  `.execute(db)

  // 3. Create new worktrees table with FK
  await db.schema.createTable("mux_worktrees_new")
    .addColumn("id", "integer", (cb) => cb.primaryKey().autoIncrement())
    .addColumn("project_id", "integer", (cb) =>
      cb.notNull().references("mux_projects.id").onDelete("cascade")
    )
    .addColumn("branch", "text", (cb) => cb.notNull())
    .addColumn("tmux_window", "text")
    .addUniqueConstraint("uq_mux_worktrees_project_branch", ["project_id", "branch"])
    .execute()

  // 4. Copy data (tmux_window set to NULL — can't convert index→@N ID)
  await sql`
    INSERT INTO mux_worktrees_new (project_id, branch)
    SELECT p.id, w.branch
    FROM mux_worktrees w
    JOIN mux_projects p ON p.path = w.repo_root
  `.execute(db)

  // 5. Drop old, rename new
  await db.schema.dropTable("mux_worktrees").execute()
  await sql`ALTER TABLE mux_worktrees_new RENAME TO mux_worktrees`.execute(db)
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any -- Kysely migrations use untyped DB
export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable("mux_worktrees").ifExists().execute()
  await db.schema.dropTable("mux_projects").ifExists().execute()

  // Recreate original schema
  await db.schema.createTable("mux_worktrees")
    .addColumn("id", "integer", (cb) => cb.primaryKey().autoIncrement())
    .addColumn("repo_root", "text", (cb) => cb.notNull())
    .addColumn("branch", "text", (cb) => cb.notNull())
    .addColumn("worktree_path", "text", (cb) => cb.notNull())
    .addColumn("tmux_session", "text")
    .addColumn("tmux_window_index", "integer")
    .addColumn("created_at", "text", (cb) =>
      cb.notNull().defaultTo(sql`(strftime('%Y-%m-%dT%H:%M:%fZ','now'))`)
    )
    .addColumn("last_accessed_at", "text")
    .addColumn("status", "text", (cb) =>
      cb.notNull().defaultTo("active").check(
        sql`status IN ('active', 'merged', 'orphaned')`
      )
    )
    .addUniqueConstraint("uq_mux_worktrees_repo_branch", ["repo_root", "branch"])
    .execute()
}
