import type { MigrationProvider } from "kysely"
import { up as up001, down as down001 } from "./migrations/001-locks"
import { up as up002, down as down002 } from "./migrations/002-mux-worktrees"
import { up as up003, down as down003 } from "./migrations/003-normalize-mux"
import { up as up004, down as down004 } from "./migrations/004-drop-tmux-columns"
import { up as up005, down as down005 } from "./migrations/005-worktree-created-at"
import { up as up006, down as down006 } from "./migrations/006-drop-worktree-unique"
import { up as up007, down as down007 } from "./migrations/007-worktree-deleted-at"
import { up as up008, down as down008 } from "./migrations/008-project-uuid-id"
import { up as up009, down as down009 } from "./migrations/009-worktree-uuid-id"

export const migrationProvider: MigrationProvider = {
  getMigrations() {
    return Promise.resolve({
      "001_locks": { up: up001, down: down001 },
      "002_mux_worktrees": { up: up002, down: down002 },
      "003_normalize_mux": { up: up003, down: down003 },
      "004_drop_tmux_columns": { up: up004, down: down004 },
      "005_worktree_created_at": { up: up005, down: down005 },
      "006_drop_worktree_unique": { up: up006, down: down006 },
      "007_worktree_deleted_at": { up: up007, down: down007 },
      "008_project_uuid_id": { up: up008, down: down008 },
      "009_worktree_uuid_id": { up: up009, down: down009 },
    })
  },
}
