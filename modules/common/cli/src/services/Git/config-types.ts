import { Schema } from "effect"

export const PaneDefinitionSchema = Schema.Struct({
  command: Schema.optional(Schema.String),
  split: Schema.optional(Schema.Literal("vertical", "horizontal")),
  percentage: Schema.optional(Schema.Number),
  focus: Schema.optional(Schema.Boolean),
})

const WorktreeConfigSchema = Schema.Struct({
  files: Schema.optionalWith(
    Schema.Struct({
      copy: Schema.optionalWith(Schema.Array(Schema.String), { default: () => [] as readonly string[] }),
      link: Schema.optionalWith(Schema.Array(Schema.String), { default: () => [] as readonly string[] }),
    }),
    { default: () => ({ copy: [] as readonly string[], link: [] as readonly string[] }) },
  ),
  panes: Schema.optionalWith(Schema.Array(PaneDefinitionSchema), {
    default: () => [
      { command: "nvim ." },
      { command: "$SHELL", split: "vertical" as const, percentage: 33, focus: true },
      { split: "horizontal" as const },
    ],
  }),
  merge_strategy: Schema.optionalWith(Schema.Literal("rebase", "squash", "merge"), { default: () => "rebase" as const }),
  post_create: Schema.optionalWith(Schema.Array(Schema.String), { default: () => [] as readonly string[] }),
  pre_merge: Schema.optionalWith(Schema.Array(Schema.String), { default: () => [] as readonly string[] }),
})

export const ProjectConfigSchema = Schema.Struct({
  name: Schema.optional(Schema.String),
  tmux_session: Schema.optional(Schema.String),
  primary_branch: Schema.optionalWith(Schema.String, { default: () => "main" }),
  worktree: Schema.optionalWith(WorktreeConfigSchema, {
    default: () => Schema.decodeUnknownSync(WorktreeConfigSchema)({}),
  }),
})

export type PaneDefinition = Schema.Schema.Type<typeof PaneDefinitionSchema>
export type ProjectConfig = Schema.Schema.Type<typeof ProjectConfigSchema>
