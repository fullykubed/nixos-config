import { sql, type Kysely } from "kysely"
import type { DB } from "../types"

export async function up(db: Kysely<DB>): Promise<void> {
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

export async function down(db: Kysely<DB>): Promise<void> {
  await db.schema.dropTable("mux_worktrees").execute()
}